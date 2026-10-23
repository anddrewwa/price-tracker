import 'package:flutter_test/flutter_test.dart';
import 'package:price_tracker/main.dart';
import 'package:price_tracker/services/price_service.dart';
import 'package:price_tracker/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the empty state on first launch', (tester) async {
    await tester.pumpWidget(const PriceTrackerApp());
    await tester.pumpAndSettle();
    expect(find.text('Nothing tracked yet'), findsOneWidget);
  });

  test('tracking a demo item, then a sale, creates one alert', () async {
    final item = await PriceService.addItem('demo://headphones', targetPrice: 200);
    expect(item.currentPrice, 249.99);
    expect(item.name, 'Wireless Noise-Cancelling Headphones');
    expect(await Store.loadAlerts(), isEmpty);

    await Store.setDemoPrice('headphones', 189.99);
    await PriceService.checkItem(item.id);
    final alerts = await Store.loadAlerts();
    expect(alerts, hasLength(1));
    expect(alerts.first.message, contains('target'));

    // Same price again: no duplicate alert.
    await PriceService.checkItem(item.id);
    expect(await Store.loadAlerts(), hasLength(1));
  });

  test('finds other demo shops and tracks the best price across them', () async {
    final item = await PriceService.addItem('demo://headphones', targetPrice: 200);

    final found = await PriceService.findOffers(item);
    expect(found.map((r) => r.store), ['BargainBay', 'MegaMart']); // cheapest first, own store skipped

    for (final result in found) {
      await PriceService.addOffer(item.id, result.url);
    }
    var updated = (await Store.getItem(item.id))!;
    expect(updated.offers, hasLength(3));
    expect(updated.bestOffer?.store, 'BargainBay');
    expect(updated.currentPrice, 239.99);
    expect(await Store.loadAlerts(), isEmpty); // 4% cheaper isn't a sale

    // A sale at another shop drops below the target and names that shop.
    await Store.setDemoPrice('headphones/megamart', 189.99);
    updated = (await PriceService.checkItem(item.id))!;
    expect(updated.currentPrice, 189.99);
    expect(updated.bestOffer?.store, 'MegaMart');
    final alerts = await Store.loadAlerts();
    expect(alerts, hasLength(1));
    expect(alerts.first.message, contains('at MegaMart'));

    // Removing that shop falls back to the next best.
    await PriceService.removeOffer(item.id, 'demo://headphones/megamart');
    updated = (await Store.getItem(item.id))!;
    expect(updated.offers, hasLength(2));
    expect(updated.currentPrice, 239.99);
  });
}
