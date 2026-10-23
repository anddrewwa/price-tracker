/// Find the same product at other stores by reading their search pages.
///
/// Pure parsing and matching (no network) so it's easy to unit test. Only
/// stores whose search pages work without a browser are supported: many big
/// retailers (Walmart, Target, eBay, Best Buy) block automated searches, but
/// a link from any of them can still be added by hand.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'scraper.dart';

class SearchResult {
  final String store;
  final String title;
  final String url;
  final double price;
  final double? originalPrice;

  const SearchResult({
    required this.store,
    required this.title,
    required this.url,
    required this.price,
    this.originalPrice,
  });
}

/// A store whose search results we know how to read.
class SearchSite {
  final String store;
  final Uri Function(String query) searchUrl;
  final List<SearchResult> Function(String html) parse;

  const SearchSite(this.store, this.searchUrl, this.parse);
}

final searchSites = <SearchSite>[
  SearchSite(
    'Amazon',
    (q) => Uri.https('www.amazon.com', '/s', {'k': q}),
    parseAmazonSearch,
  ),
  SearchSite(
    'Newegg',
    (q) => Uri.https('www.newegg.com', '/p/pl', {'d': q}),
    parseNeweggSearch,
  ),
];

double? _offscreenPrice(Element? el) => parsePrice(el?.querySelector('.a-offscreen')?.text);

List<SearchResult> parseAmazonSearch(String html) {
  final doc = html_parser.parse(html);
  final results = <SearchResult>[];
  for (final card in doc.querySelectorAll('[data-component-type="s-search-result"]')) {
    final asin = card.attributes['data-asin'] ?? '';
    // Cards can have a short brand line ("Sony") in its own h2; the title is the longest.
    var title = '';
    for (final h2 in card.querySelectorAll('h2')) {
      final text = (h2.attributes['aria-label'] ?? h2.text).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.length > title.length) title = text;
    }
    if (asin.isEmpty || title.isEmpty) continue;

    // The first a-price that isn't the crossed-out list price.
    Element? current;
    Element? was;
    for (final el in card.querySelectorAll('.a-price')) {
      if (el.classes.contains('a-text-price')) {
        was ??= el;
      } else {
        current ??= el;
      }
    }
    final price = _offscreenPrice(current);
    if (price == null) continue;
    final original = _offscreenPrice(was);
    results.add(SearchResult(
      store: 'Amazon',
      title: title,
      url: 'https://www.amazon.com/dp/$asin',
      price: price,
      originalPrice: original != null && original > price ? original : null,
    ));
  }
  return results;
}

List<SearchResult> parseNeweggSearch(String html) {
  final doc = html_parser.parse(html);
  final results = <SearchResult>[];
  for (final titleEl in doc.querySelectorAll('.item-title')) {
    // The title sits inside (or is) the link to the product page.
    Element? link = titleEl;
    while (link != null && link.localName != 'a') {
      link = link.parent;
    }
    final href = link?.attributes['href'];
    if (link == null || href == null) continue;
    final price = parsePrice(link.querySelector('.price-current')?.text);
    if (price == null) continue;
    final original = parsePrice(link.querySelector('.price-was')?.text);
    final url = Uri.parse('https://www.newegg.com/').resolve(href).toString();
    results.add(SearchResult(
      store: 'Newegg',
      title: titleEl.text.trim(),
      url: url,
      price: price,
      originalPrice: original != null && original > price ? original : null,
    ));
  }
  return results;
}

// ---------- matching ----------

const _stopWords = {'the', 'and', 'with', 'for', 'a', 'an', 'of', 'in', 'to', 'by', 'new'};

/// Words that mean "a thing for the product", not the product itself.
const _accessoryWords = {
  'case', 'cover', 'replacement', 'pads', 'cushions', 'cushion', 'stand', 'holder',
  'skin', 'protector', 'adapter', 'cable', 'charger', 'compatible', 'mount', 'sleeve',
};

/// Words that mean "not new".
const _conditionWords = {'renewed', 'refurbished', 'used', 'pre-owned', 'open-box'};

Set<String> _tokens(String text) => text
    .toLowerCase()
    .replaceAll('cancelling', 'canceling') // UK and US spellings
    .replaceAll(RegExp(r'[^a-z0-9\-. ]'), ' ')
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(RegExp(r'^[\-.]+|[\-.]+$'), ''))
    .where((w) => w.length > 1 && !_stopWords.contains(w))
    .toSet();

/// What to type into a store's search box: the first few meaningful words
/// of the name (store titles get long and too-specific searches find nothing).
String searchQuery(String name) {
  final words = name
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
      .split(RegExp(r'[\s,|/]+'))
      .where((w) => w.isNotEmpty)
      .take(7);
  return words.join(' ');
}

/// 0..1: how likely [candidate] is the same product as [name].
///
/// The share of the name's words found in the candidate, with model numbers
/// (words with digits) counting double. Scores 0 when the candidate shares
/// none of the name's model numbers (a different model from the same brand),
/// or is an accessory or used item the name doesn't mention.
double matchScore(String name, String candidate) {
  final want = _tokens(searchQuery(name));
  final got = _tokens(candidate);
  if (want.isEmpty) return 0;
  for (final word in {..._accessoryWords, ..._conditionWords}) {
    if (got.contains(word) && !want.contains(word)) return 0;
  }
  final models = want.where((w) => RegExp(r'\d').hasMatch(w));
  if (models.isNotEmpty && !models.any(got.contains)) return 0;
  var total = 0.0;
  var found = 0.0;
  for (final word in want) {
    final weight = RegExp(r'\d').hasMatch(word) ? 2.0 : 1.0;
    total += weight;
    if (got.contains(word)) found += weight;
  }
  return found / total;
}

/// Results good enough to suggest, cheapest first, skipping links already tracked.
List<SearchResult> pickMatches(String name, Iterable<SearchResult> results,
    {Set<String> exclude = const {}, double minScore = 0.6, int limit = 8}) {
  final seen = <String>{...exclude};
  final picked = <SearchResult>[];
  for (final r in results) {
    if (seen.contains(r.url) || matchScore(name, r.title) < minScore) continue;
    seen.add(r.url);
    picked.add(r);
  }
  picked.sort((a, b) => a.price.compareTo(b.price));
  return picked.take(limit).toList();
}
