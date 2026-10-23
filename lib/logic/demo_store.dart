/// A fake store built into the app, for reliable class demos.
///
/// Demo items use links like `demo://headphones`. Their "page" is generated
/// here and goes through the same scraper as real pages. Change a price on
/// the Demo Store screen, pull to refresh, and the alert fires.
library;

import 'dart:convert';

class DemoProduct {
  final String slug;
  final String name;
  final double regular;

  const DemoProduct(this.slug, this.name, this.regular);

  String get url => 'demo://$slug';
}

const demoProducts = <DemoProduct>[
  DemoProduct('headphones', 'Wireless Noise-Cancelling Headphones', 249.99),
  DemoProduct('keyboard', 'Mechanical Keyboard (Brown Switches)', 89.99),
  DemoProduct('ssd', '1TB NVMe SSD', 79.99),
];

DemoProduct? demoProduct(String slug) {
  for (final product in demoProducts) {
    if (product.slug == slug) return product;
  }
  return null;
}

/// Extra pretend stores that sell the same demo products, so "find the best
/// price" can be shown without the internet. The first one is the original
/// Demo Store (links like `demo://headphones`); the others use
/// `demo://headphones/megamart`.
class DemoShop {
  final String id;
  final String name;
  final double priceFactor; // regular price relative to the Demo Store

  const DemoShop(this.id, this.name, this.priceFactor);
}

const demoShops = <DemoShop>[
  DemoShop('', 'Demo Store', 1.0),
  DemoShop('megamart', 'MegaMart', 1.06),
  DemoShop('bargainbay', 'BargainBay', 0.96),
];

DemoShop? demoShop(String id) {
  for (final shop in demoShops) {
    if (shop.id == id) return shop;
  }
  return null;
}

String demoUrl(DemoProduct product, DemoShop shop) =>
    shop.id.isEmpty ? product.url : '${product.url}/${shop.id}';

/// Key for a product's price at a shop in saved demo prices.
String demoKey(DemoProduct product, DemoShop shop) =>
    shop.id.isEmpty ? product.slug : '${product.slug}/${shop.id}';

/// Regular price at a shop, rounded to end in .99 like a real store.
double demoRegular(DemoProduct product, DemoShop shop) =>
    shop.priceFactor == 1.0 ? product.regular : (product.regular * shop.priceFactor).floor() + 0.99;

/// The HTML a real store page might serve for this product at this price.
String demoPage(DemoProduct product, double price, {DemoShop shop = const DemoShop('', 'Demo Store', 1.0)}) {
  final regular = demoRegular(product, shop);
  final jsonLd = jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'Product',
    'name': product.name,
    'offers': {'@type': 'Offer', 'price': price.toStringAsFixed(2), 'priceCurrency': 'USD'},
  });
  final was = price < regular
      ? '<del class="was-price">\$${regular.toStringAsFixed(2)}</del>'
      : '';
  return '''<!doctype html>
<html><head><title>${htmlEscape.convert(product.name)} | ${htmlEscape.convert(shop.name)}</title>
<script type="application/ld+json">$jsonLd</script></head>
<body><h1>${htmlEscape.convert(product.name)}</h1>
<p><span class="price">\$${price.toStringAsFixed(2)}</span> $was</p></body></html>''';
}
