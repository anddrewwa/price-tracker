/// Friendly store names for links ("https://www.bestbuy.com/..." -> "Best Buy").
library;

import 'demo_store.dart';

const _knownStores = {
  'amazon.': 'Amazon',
  'newegg.': 'Newegg',
  'bestbuy.': 'Best Buy',
  'walmart.': 'Walmart',
  'target.': 'Target',
  'ebay.': 'eBay',
  'bhphotovideo.': 'B&H',
  'costco.': 'Costco',
  'homedepot.': 'Home Depot',
  'lowes.': "Lowe's",
  'microcenter.': 'Micro Center',
  'apple.com': 'Apple',
};

String storeName(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return 'Store';
  if (uri.scheme == 'demo') {
    final shopId = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return demoShop(shopId)?.name ?? 'Demo Store';
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|smile)\.'), '');
  for (final entry in _knownStores.entries) {
    if (host.contains(entry.key)) return entry.value;
  }
  final label = host.split('.').first;
  return label.isEmpty ? 'Store' : label[0].toUpperCase() + label.substring(1);
}
