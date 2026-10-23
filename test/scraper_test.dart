import 'package:flutter_test/flutter_test.dart';
import 'package:price_tracker/logic/demo_store.dart';
import 'package:price_tracker/logic/scraper.dart';

void main() {
  test('parsePrice handles common formats', () {
    expect(parsePrice(r'$1,299.99'), 1299.99);
    expect(parsePrice('USD 15'), 15.0);
    expect(parsePrice(42), 42.0);
    expect(parsePrice('free'), isNull);
    expect(parsePrice('0.00'), isNull);
  });

  test('reads JSON-LD product data', () {
    const html = '''<html><head><script type="application/ld+json">
      {"@context": "https://schema.org", "@type": "Product", "name": "Cool Mug",
       "offers": {"@type": "Offer", "price": "12.50", "priceCurrency": "USD"}}
      </script></head><body><h1>ignored</h1></body></html>''';
    final info = extract(html);
    expect(info.price, 12.50);
    expect(info.name, 'Cool Mug');
  });

  test('reads JSON-LD inside @graph with a list of offers', () {
    const html = '''<script type="application/ld+json">
      {"@graph": [{"@type": "WebPage"},
                  {"@type": ["Product"], "name": "Lamp",
                   "offers": [{"@type": "Offer", "price": 30}]}]}
      </script>''';
    expect(extract(html).price, 30.0);
  });

  test('falls back to meta tags', () {
    const html = '<meta property="product:price:amount" content="19.99"><title>Thing</title>';
    final info = extract(html);
    expect(info.price, 19.99);
    expect(info.name, 'Thing');
  });

  test('falls back to HTML and finds the was price', () {
    const html = r'<h1>Desk</h1><span class="price">$150.00</span><del>$200.00</del>';
    final info = extract(html);
    expect(info.price, 150.0);
    expect(info.originalPrice, 200.0);
    expect(info.name, 'Desk');
  });

  test('ignores a was price that is not higher', () {
    const html = r'<span class="price">$150.00</span><del>$120.00</del>';
    expect(extract(html).originalPrice, isNull);
  });

  test('no price found', () {
    expect(extract('<p>Hello</p>').price, isNull);
  });

  test('demo store pages go through the scraper correctly', () {
    final product = demoProducts.first;
    final full = extract(demoPage(product, product.regular));
    expect(full.price, product.regular);
    expect(full.originalPrice, isNull);
    expect(full.name, product.name);

    final sale = extract(demoPage(product, 189.99));
    expect(sale.price, 189.99);
    expect(sale.originalPrice, product.regular);
  });
}
