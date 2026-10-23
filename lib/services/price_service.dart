/// Ties everything together: download a page, find the price, decide whether
/// to alert, save the result. Used by both the screens and background checks.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logic/checker.dart';
import '../logic/demo_store.dart';
import '../logic/scraper.dart';
import '../logic/search.dart';
import '../models.dart';
import 'notifier.dart';
import 'storage.dart';

class PriceService {
  // Keep the Chrome version close to the real Chrome network stack (Cronet)
  // the request comes from: stores block versions that don't match.
  static const _mobileAgent = 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36';
  static const _desktopAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36';

  /// Amazon blocks mobile requests more often; Newegg only lists search
  /// results in its mobile page. Everyone else gets the mobile page.
  static Map<String, String> _headersFor(Uri uri) => {
        'User-Agent': uri.host.contains('amazon.') ? _desktopAgent : _mobileAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };
  static const _maxHistory = 100;

  /// On Android, requests go through Chrome's network stack (Cronet). Many
  /// stores block Dart's own HTTP client but let Chrome through.
  static final http.Client _http = _makeClient();

  static http.Client _makeClient() {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return CronetClient.fromCronetEngine(
          CronetEngine.build(cacheMode: CacheMode.memory, cacheMaxSize: 2 * 1024 * 1024),
          closeEngine: true,
        );
      } catch (e) {
        debugPrint('Cronet unavailable, using the default HTTP client: $e');
      }
    }
    return http.Client();
  }

  /// Returns the page HTML. demo:// links come from the built-in demo store.
  static Future<String> fetchPage(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme == 'demo') {
      final product = demoProduct(uri.host);
      final shop = demoShop(uri.pathSegments.isEmpty ? '' : uri.pathSegments.first);
      if (product == null || shop == null) throw Exception('No such demo product');
      final prices = await Store.demoPrices();
      return demoPage(product, prices[demoKey(product, shop)] ?? demoRegular(product, shop), shop: shop);
    }
    final response = await _http.get(uri, headers: _headersFor(uri)).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// Start tracking a link and check it right away.
  static Future<TrackedItem> addItem(String url, {double? targetPrice, String? name}) async {
    final item = TrackedItem(
      id: Store.newId(),
      name: name ?? url, // replaced by the real product name after the first check
      url: url,
      targetPrice: targetPrice,
    );
    await Store.addItem(item);
    return await checkItem(item.id) ?? item;
  }

  /// Load one store's page and update its price. Returns the page's product name.
  static Future<String?> _checkOffer(Offer offer, DateTime now) async {
    offer.lastChecked = now;
    PriceInfo info;
    try {
      info = extract(await fetchPage(offer.url));
    } catch (_) {
      offer.lastError = "Couldn't load the page";
      return null;
    }
    final price = info.price;
    if (price == null) {
      offer.lastError = "Couldn't find a price on the page";
      return info.name;
    }
    offer
      ..price = price
      ..originalPrice = info.originalPrice
      ..lastError = null;
    return info.name;
  }

  /// Check every store for one item. Returns the updated item, or null if it no longer exists.
  static Future<TrackedItem?> checkItem(String id) async {
    final item = await Store.getItem(id);
    if (item == null) return null;
    final now = DateTime.now();

    String? foundName;
    for (final (i, offer) in item.offers.indexed) {
      if (i > 0 && !offer.isDemo) {
        await Future.delayed(const Duration(milliseconds: 500)); // be polite to real sites
      }
      final name = await _checkOffer(offer, now);
      if (offer.url == item.url) foundName = name;
    }

    final best = item.bestOffer;
    item.lastChecked = now;
    if (best == null) {
      item.lastError = item.offers.first.lastError ?? "Couldn't find a price";
      await Store.updateItem(item);
      return item;
    }
    final price = best.price!;
    // Only report a problem if no store answered at all; per-store errors show in the comparison.
    item.lastError = null;

    if (item.name == item.url && foundName != null && foundName.isNotEmpty) {
      item.name = foundName.length > 200 ? foundName.substring(0, 200) : foundName;
    }

    // Highest price seen so far is our guess at the "regular" price.
    // Read it BEFORE adding the new price to the history.
    final regular = item.history.isEmpty ? null : item.history.map((p) => p.price).reduce(max);

    item
      ..currentPrice = price
      ..originalPrice = best.originalPrice
      ..history.add(PricePoint(price, now));
    if (item.history.length > _maxHistory) item.history.removeAt(0);

    final decision = evaluate(
      name: item.name,
      price: price,
      store: item.offers.length > 1 ? best.store : null,
      targetPrice: item.targetPrice,
      originalPrice: best.originalPrice,
      regularPrice: regular,
      lastAlertPrice: item.lastAlertPrice,
    );
    item.lastAlertPrice = decision.newLastAlertPrice;
    await Store.updateItem(item);

    final message = decision.message;
    if (decision.alert && message != null) {
      await Store.addAlert(item.id, message);
      await Notifier.show('Price alert', message);
    }
    return item;
  }

  static Future<void> checkAll() async {
    for (final item in await Store.loadItems()) {
      await checkItem(item.id);
      if (!item.isDemo) {
        await Future.delayed(const Duration(seconds: 1)); // be polite to real sites
      }
    }
  }

  /// Search other stores for the same product. Demo items search the demo shops.
  static Future<List<SearchResult>> findOffers(TrackedItem item) async {
    final tracked = item.offers.map((o) => o.url).toSet();
    if (item.isDemo) {
      final product = demoProduct(Uri.parse(item.url).host);
      if (product == null) return [];
      final prices = await Store.demoPrices();
      return pickMatches(item.name, [
        for (final shop in demoShops)
          SearchResult(
            store: shop.name,
            title: product.name,
            url: demoUrl(product, shop),
            price: prices[demoKey(product, shop)]!,
          ),
      ], exclude: tracked);
    }

    final query = searchQuery(item.name);
    final pages = await Future.wait([
      for (final site in searchSites)
        _http
            .get(site.searchUrl(query), headers: _headersFor(site.searchUrl(query)))
            .timeout(const Duration(seconds: 15))
            .then((r) => r.statusCode == 200
                ? site.parse(utf8.decode(r.bodyBytes, allowMalformed: true))
                : <SearchResult>[])
            .catchError((_) => <SearchResult>[]),
    ]);
    // Don't suggest the store the item already comes from.
    final ownStores = item.offers.map((o) => o.store).toSet();
    return pickMatches(
      item.name,
      pages.expand((p) => p).where((r) => !ownStores.contains(r.store)),
      exclude: tracked,
    );
  }

  /// Add another store's link to an item and re-check prices.
  static Future<TrackedItem?> addOffer(String id, String url) async {
    final item = await Store.getItem(id);
    if (item == null) return null;
    if (!item.offers.any((o) => o.url == url)) {
      item.offers.add(Offer(url: url));
      await Store.updateItem(item);
    }
    return checkItem(id);
  }

  /// Stop checking one store. The item's original link can't be removed.
  static Future<void> removeOffer(String id, String url) async {
    final item = await Store.getItem(id);
    if (item == null || url == item.url) return;
    item.offers.removeWhere((o) => o.url == url);
    final best = item.bestOffer;
    item
      ..currentPrice = best?.price
      ..originalPrice = best?.originalPrice;
    await Store.updateItem(item);
  }

  /// Change the target price. Resets alert memory so the new target can fire.
  static Future<void> setTarget(String id, double? target) async {
    final item = await Store.getItem(id);
    if (item == null) return;
    item
      ..targetPrice = target
      ..lastAlertPrice = null;
    await Store.updateItem(item);
  }
}
