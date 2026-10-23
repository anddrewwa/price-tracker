/// Pull the price out of a product page's HTML.
///
/// Strategies, most reliable first:
///   1. JSON-LD structured data (<script type="application/ld+json">). Many
///      stores publish this for Google Shopping, so it's the cleanest source.
///   2. Meta tags like <meta property="product:price:amount">.
///   3. Microdata (itemprop="price"), data-price attributes, and elements
///      whose class contains "price".
///
/// Limitation: some big retailers block automated requests or render prices
/// with JavaScript, so this won't work on every site.
library;

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class PriceInfo {
  double? price;
  double? originalPrice; // "was" price, if the page shows one
  String? name;

  PriceInfo({this.price, this.originalPrice, this.name});
}

final _number = RegExp(r'\d+(?:\.\d+)?');

/// Turn "$1,299.99", "USD 15", 15 or "15.00" into a double.
double? parsePrice(dynamic value) {
  if (value == null) return null;
  if (value is num) return value > 0 ? value.toDouble() : null;
  final match = _number.firstMatch(value.toString().replaceAll(',', ''));
  if (match == null) return null;
  final price = double.parse(match.group(0)!);
  return price > 0 ? price : null;
}

bool _hasDigit(String text) => RegExp(r'\d').hasMatch(text);

// ---------- strategy 1: JSON-LD ----------

/// Yield every object inside a JSON-LD blob (handles lists and @graph).
Iterable<Map<String, dynamic>> _walk(dynamic node) sync* {
  if (node is Map) {
    final map = Map<String, dynamic>.from(node);
    yield map;
    for (final value in map.values) {
      yield* _walk(value);
    }
  } else if (node is List) {
    for (final value in node) {
      yield* _walk(value);
    }
  }
}

bool _isProduct(Map<String, dynamic> node) {
  final type = node['@type'];
  return type == 'Product' || (type is List && type.contains('Product'));
}

PriceInfo? _fromJsonLd(Document doc) {
  for (final tag in doc.querySelectorAll('script')) {
    if ((tag.attributes['type'] ?? '').toLowerCase() != 'application/ld+json') continue;
    dynamic data;
    try {
      data = jsonDecode(tag.text);
    } catch (_) {
      continue;
    }
    for (final node in _walk(data)) {
      if (!_isProduct(node)) continue;
      var offers = node['offers'];
      if (offers is List) offers = offers.isNotEmpty ? offers.first : null;
      if (offers is! Map) continue;
      final price = parsePrice(offers['price'] ?? offers['lowPrice']);
      if (price == null) continue;

      // Some stores include the list price in priceSpecification.
      double? original;
      for (final spec in _walk(offers['priceSpecification'])) {
        if ((spec['priceType'] ?? '').toString().contains('ListPrice')) {
          original = parsePrice(spec['price']);
        }
      }
      final name = node['name'];
      return PriceInfo(price: price, originalPrice: original, name: name is String ? name : null);
    }
  }
  return null;
}

// ---------- strategies 2 and 3: meta tags and HTML ----------

double? _fromMeta(Document doc) {
  for (final el in doc.querySelectorAll('meta')) {
    final key = el.attributes['property'] ?? el.attributes['name'];
    if (key == 'product:price:amount' || key == 'og:price:amount') {
      final price = parsePrice(el.attributes['content']);
      if (price != null) return price;
    }
  }
  for (final el in doc.querySelectorAll('*')) {
    if (el.attributes['itemprop'] == 'price') {
      final price = parsePrice(el.attributes['content'] ?? el.text);
      if (price != null) return price;
    }
  }
  return null;
}

/// Big stores that publish no structured data, and where their price lives.
const _storePriceSelectors = [
  '#apex-pricetopay-accessibility-label', // Amazon
  '.priceToPay',
  '#corePrice_feature_div .a-price',
  '#corePriceDisplay_desktop_feature_div .a-price',
  '.product-buy-box .price-current', // Newegg
];

/// Amazon splits prices into hidden text plus visible "whole" and "fraction" parts.
double? _priceText(Element el) {
  final hidden = parsePrice(el.querySelector('.a-offscreen')?.text);
  if (hidden != null) return hidden;
  final whole = el.querySelector('.a-price-whole')?.text.replaceAll(RegExp(r'[^0-9]'), '');
  if (whole != null && whole.isNotEmpty) {
    final fraction = el.querySelector('.a-price-fraction')?.text.replaceAll(RegExp(r'[^0-9]'), '');
    return parsePrice('$whole.${fraction == null || fraction.isEmpty ? '00' : fraction}');
  }
  return parsePrice(el.text);
}

double? _fromStoreSelectors(Document doc) {
  for (final selector in _storePriceSelectors) {
    final el = doc.querySelector(selector);
    final price = el == null ? null : _priceText(el);
    if (price != null) return price;
  }
  return null;
}

bool _looksLikeOldPrice(Element el) {
  final cls = el.className.toLowerCase();
  return el.localName == 'del' ||
      el.localName == 's' ||
      cls.contains('was') ||
      cls.contains('original') ||
      cls.contains('list-price');
}

double? _fromHtml(Document doc) {
  final all = doc.querySelectorAll('*');
  for (final el in all) {
    final value = el.attributes['data-price'];
    if (value != null) {
      final price = parsePrice(value);
      if (price != null) return price;
    }
  }
  final byId = doc.querySelector('#price');
  if (byId != null && _hasDigit(byId.text)) return parsePrice(byId.text);
  for (final el in all) {
    if (el.className.toLowerCase().contains('price') &&
        !_looksLikeOldPrice(el) &&
        _hasDigit(el.text)) {
      return parsePrice(el.text);
    }
  }
  return null;
}

double? _originalFromHtml(Document doc) {
  final all = doc.querySelectorAll('*');
  for (final el in all) {
    final value = el.attributes['data-original-price'];
    if (value != null) return parsePrice(value);
  }
  for (final el in all) {
    if (_looksLikeOldPrice(el) && _hasDigit(el.text)) return parsePrice(el.text);
  }
  return null;
}

String? _rawName(Document doc) {
  for (final el in doc.querySelectorAll('meta')) {
    if (el.attributes['property'] == 'og:title') {
      final content = el.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) return content;
    }
  }
  final product = doc.querySelector('#productTitle')?.text.trim(); // Amazon
  if (product != null && product.isNotEmpty) return product;
  final h1 = doc.querySelector('h1')?.text.trim();
  if (h1 != null && h1.isNotEmpty) return h1;
  final title = doc.querySelector('title')?.text.trim();
  if (title != null && title.isNotEmpty) return title;
  return null;
}

/// "Amazon.com: Sony Headphones : Electronics" -> "Sony Headphones".
String cleanName(String name) {
  var n = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceFirst(RegExp(r'^(Amazon\.com|Newegg\.com|Walmart\.com|Target)\s*:\s*', caseSensitive: false), '');
  n = n.replaceFirst(RegExp(r'\s+:\s+[^:]+$'), ''); // trailing " : Category"
  n = n.replaceFirst(RegExp(r'\s+[-|]\s+(Newegg\.com|Walmart\.com|Target|Best Buy|Amazon\.com)$', caseSensitive: false), '');
  return n;
}

String? _name(Document doc) {
  final raw = _rawName(doc);
  return raw == null ? null : cleanName(raw);
}

PriceInfo extract(String html) {
  final doc = html_parser.parse(html);
  final info = _fromJsonLd(doc) ??
      PriceInfo(price: _fromMeta(doc) ?? _fromStoreSelectors(doc) ?? _fromHtml(doc));
  info.originalPrice ??= _originalFromHtml(doc);

  // A "was" price that isn't higher than the current price isn't a discount.
  final price = info.price;
  final original = info.originalPrice;
  if (price != null && original != null && original <= price) {
    info.originalPrice = null;
  }
  info.name ??= _name(doc);
  return info;
}
