/// The decision logic: should we alert the user about this price?
///
/// A pure function (no storage, no network) so it's easy to unit test.
library;

import 'format.dart';

/// Ignore tiny fluctuations: a drop must be at least this big to count as a sale.
const double minSalePercent = 5.0;

class Decision {
  final bool alert;
  final String? message;

  /// What to store as the item's lastAlertPrice after this check.
  final double? newLastAlertPrice;

  const Decision(this.alert, this.message, this.newLastAlertPrice);
}

/// [price]          the price we just found (the best across stores)
/// [store]          where that price is, named in the alert (optional)
/// [targetPrice]    user's "tell me at or below this" (optional)
/// [originalPrice]  a "was" price the store shows on the page (optional)
/// [regularPrice]   highest price we've recorded before (our own baseline)
/// [lastAlertPrice] price we last alerted at; null if no active alert
Decision evaluate({
  required String name,
  required double price,
  String? store,
  double? targetPrice,
  double? originalPrice,
  double? regularPrice,
  double? lastAlertPrice,
}) {
  final reasons = <String>[];

  if (targetPrice != null && price <= targetPrice) {
    reasons.add('at or below your target of ${money(targetPrice)}');
  }

  // Prefer the store's own "was" price; fall back to our price history.
  final reference =
      (originalPrice != null && originalPrice > price) ? originalPrice : regularPrice;
  if (reference != null && reference > price) {
    final percentOff = (reference - price) / reference * 100;
    if (percentOff >= minSalePercent) {
      reasons.add('on sale, ${percentOff.round()}% off ${money(reference)}');
    }
  }

  if (reasons.isEmpty) {
    // Deal is over: forget the last alert so the next deal notifies again.
    return const Decision(false, null, null);
  }

  if (lastAlertPrice != null && price >= lastAlertPrice) {
    // Already told them about this deal and it hasn't gotten better.
    return Decision(false, null, lastAlertPrice);
  }

  final where = store == null ? '' : ' at $store';
  return Decision(true, '$name is now ${money(price)}$where: ${reasons.join(' and ')}.', price);
}
