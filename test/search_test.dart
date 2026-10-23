import 'package:flutter_test/flutter_test.dart';
import 'package:price_tracker/logic/search.dart';
import 'package:price_tracker/logic/stores.dart';
import 'package:price_tracker/models.dart';

// Trimmed-down copies of each store's search result markup.
const amazonHtml = '''
<div data-component-type="s-search-result" data-asin="B0TEST0001">
  <h2><span>Sony</span></h2>
  <h2 aria-label="Sony WH-1000XM5 Wireless Noise Canceling Headphones, Black"><span>Sony WH-1000XM5</span></h2>
  <span class="a-price"><span class="a-offscreen">\$298.00</span></span>
  <span class="a-price a-text-price"><span class="a-offscreen">List: \$399.99</span></span>
</div>
<div data-component-type="s-search-result" data-asin="B0TEST0002">
  <h2><span>Case for Sony WH-1000XM5 Headphones</span></h2>
  <span class="a-price"><span class="a-offscreen">\$19.99</span></span>
</div>
<div data-component-type="s-search-result" data-asin="">
  <h2><span>Sponsored brand banner</span></h2>
</div>''';

const neweggHtml = '''
<div class="item-cell"><a href="/p/N82E1TEST?Item=TEST">
  <div class="item-title">Sony WH-1000XM5 Wireless Noise Canceling Headphones (Silver)</div>
  <ul class="price"><li class="price-was">\$399.99<span class="price-was-data">\$399.99</span></li>
  <li class="price-current"><span class="price-current-label"></span>\$<strong>214</strong><sup>.49</sup></li></ul>
</a></div>''';

void main() {
  test('reads Amazon search results', () {
    final results = parseAmazonSearch(amazonHtml);
    expect(results, hasLength(2));
    expect(results.first.title, startsWith('Sony WH-1000XM5'));
    expect(results.first.url, 'https://www.amazon.com/dp/B0TEST0001');
    expect(results.first.price, 298.0);
    expect(results.first.originalPrice, 399.99);
  });

  test('reads Newegg search results', () {
    final results = parseNeweggSearch(neweggHtml);
    expect(results, hasLength(1));
    expect(results.first.url, 'https://www.newegg.com/p/N82E1TEST?Item=TEST');
    expect(results.first.price, 214.49);
    expect(results.first.originalPrice, 399.99);
  });

  test('matching keeps the same product and drops accessories and used items', () {
    const name = 'Sony WH-1000XM5 Wireless Noise Canceling Headphones';
    expect(matchScore(name, 'SONY WH-1000XM5 Noise-Canceling Wireless Headphones (Silver)'), greaterThan(0.6));
    expect(matchScore(name, 'Case for Sony WH-1000XM5 Headphones'), 0);
    expect(matchScore(name, 'Sony WH-1000XM5 Wireless Headphones (Renewed)'), 0);
    expect(matchScore(name, 'Sony WH-1000XM4 Wireless Noise Canceling Headphones'), 0); // different model
    expect(matchScore(name, 'WH-1000XM5 Premium Noise Cancelling Wireless Headphones, Black'), greaterThan(0.6));
    expect(matchScore(name, 'Bose QuietComfort Ultra Headphones'), lessThan(0.3));
  });

  test('pickMatches filters, skips tracked links and sorts by price', () {
    final results = [...parseAmazonSearch(amazonHtml), ...parseNeweggSearch(neweggHtml)];
    final picked = pickMatches('Sony WH-1000XM5 Wireless Noise Canceling Headphones', results);
    expect(picked.map((r) => r.store), ['Newegg', 'Amazon']);

    final skipped = pickMatches('Sony WH-1000XM5 Wireless Noise Canceling Headphones', results,
        exclude: {'https://www.newegg.com/p/N82E1TEST?Item=TEST'});
    expect(skipped.map((r) => r.store), ['Amazon']);
  });

  test('search query drops brackets and long tails', () {
    expect(searchQuery('Mechanical Keyboard (Brown Switches)'), 'Mechanical Keyboard');
    expect(searchQuery('A B C D E F G H I'), 'A B C D E F G');
  });

  test('store names from links', () {
    expect(storeName('https://www.amazon.com/dp/B0TEST'), 'Amazon');
    expect(storeName('https://www.bestbuy.com/site/x.p'), 'Best Buy');
    expect(storeName('https://shop.example.co.uk/item'), 'Shop');
    expect(storeName('demo://headphones'), 'Demo Store');
    expect(storeName('demo://headphones/megamart'), 'MegaMart');
  });

  test('items saved before multi-store support get one offer', () {
    final item = TrackedItem.fromJson({
      'id': '1',
      'name': 'Mug',
      'url': 'https://www.target.com/p/mug',
      'currentPrice': 12.5,
      'history': [],
    });
    expect(item.offers, hasLength(1));
    expect(item.offers.first.store, 'Target');
    expect(item.offers.first.price, 12.5);
    expect(item.bestOffer?.price, 12.5);

    // And survives a save/load round trip.
    final again = TrackedItem.fromJson(item.toJson());
    expect(again.offers.single.url, 'https://www.target.com/p/mug');
  });
}
