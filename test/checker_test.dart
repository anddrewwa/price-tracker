import 'package:flutter_test/flutter_test.dart';
import 'package:price_tracker/logic/checker.dart';
import 'package:price_tracker/logic/format.dart';

Decision run(double price,
        {double? target, double? original, double? regular, double? lastAlert}) =>
    evaluate(
      name: 'Mug',
      price: price,
      targetPrice: target,
      originalPrice: original,
      regularPrice: regular,
      lastAlertPrice: lastAlert,
    );

void main() {
  test('no alert when nothing interesting', () {
    final d = run(20, target: 15, regular: 20);
    expect(d.alert, isFalse);
    expect(d.newLastAlertPrice, isNull);
  });

  test('alerts at target', () {
    final d = run(15, target: 15);
    expect(d.alert, isTrue);
    expect(d.message, contains('target'));
    expect(d.newLastAlertPrice, 15);
  });

  test('alerts on sale using the store "was" price', () {
    final d = run(80, original: 100);
    expect(d.alert, isTrue);
    expect(d.message, contains('20% off'));
  });

  test('alerts on a drop versus our own history', () {
    expect(run(90, regular: 100).message, contains('10% off'));
  });

  test('tiny drop is not a sale', () {
    expect(run(98, regular: 100).alert, isFalse);
  });

  test('no repeat alert for the same deal', () {
    final d = run(80, original: 100, lastAlert: 80);
    expect(d.alert, isFalse);
    expect(d.newLastAlertPrice, 80);
  });

  test('alerts again if the price drops further', () {
    final d = run(70, original: 100, lastAlert: 80);
    expect(d.alert, isTrue);
    expect(d.newLastAlertPrice, 70);
  });

  test('deal ending resets alert memory', () {
    final d = run(100, target: 50, regular: 100, lastAlert: 80);
    expect(d.alert, isFalse);
    expect(d.newLastAlertPrice, isNull);
  });

  test('money formatting', () {
    expect(money(5), r'$5.00');
    expect(money(1299.5), r'$1,299.50');
    expect(money(1234567.891), r'$1,234,567.89');
  });
}
