/// Data classes, saved on the phone as JSON.
library;

import 'logic/stores.dart';

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();
DateTime? _toDate(dynamic v) => v == null ? null : DateTime.parse(v as String);

class PricePoint {
  final double price;
  final DateTime at;

  PricePoint(this.price, this.at);

  Map<String, dynamic> toJson() => {'price': price, 'at': at.toIso8601String()};

  factory PricePoint.fromJson(Map<String, dynamic> json) =>
      PricePoint((json['price'] as num).toDouble(), DateTime.parse(json['at'] as String));
}

enum ItemStatus { unknown, watching, onSale, belowTarget }

/// The same product at one store.
class Offer {
  final String url;
  String store;
  double? price;
  double? originalPrice; // "was" price shown by the store, if any
  DateTime? lastChecked;
  String? lastError;

  Offer({
    required this.url,
    String? store,
    this.price,
    this.originalPrice,
    this.lastChecked,
    this.lastError,
  }) : store = store ?? storeName(url);

  bool get isDemo => url.startsWith('demo://');

  Map<String, dynamic> toJson() => {
        'url': url,
        'store': store,
        'price': price,
        'originalPrice': originalPrice,
        'lastChecked': lastChecked?.toIso8601String(),
        'lastError': lastError,
      };

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        url: json['url'] as String,
        store: json['store'] as String?,
        price: _toDouble(json['price']),
        originalPrice: _toDouble(json['originalPrice']),
        lastChecked: _toDate(json['lastChecked']),
        lastError: json['lastError'] as String?,
      );
}

class TrackedItem {
  final String id;
  String name;
  final String url; // the link the item was first added with
  double? targetPrice;
  double? currentPrice; // best price across all stores
  double? originalPrice; // "was" price at the best store, if any
  DateTime? lastChecked;
  String? lastError;
  double? lastAlertPrice; // prevents repeat alerts for the same deal
  List<PricePoint> history; // best price over time
  List<Offer> offers; // every store being checked; the first is [url]

  TrackedItem({
    required this.id,
    required this.name,
    required this.url,
    this.targetPrice,
    this.currentPrice,
    this.originalPrice,
    this.lastChecked,
    this.lastError,
    this.lastAlertPrice,
    List<PricePoint>? history,
    List<Offer>? offers,
  })  : history = history ?? [],
        offers = offers ?? [Offer(url: url)];

  bool get isDemo => url.startsWith('demo://');

  /// The store with the lowest known price.
  Offer? get bestOffer {
    Offer? best;
    for (final offer in offers) {
      final price = offer.price;
      if (price != null && (best == null || price < best.price!)) best = offer;
    }
    return best;
  }

  ItemStatus get status {
    final price = currentPrice;
    if (price == null) return ItemStatus.unknown;
    final target = targetPrice;
    if (target != null && price <= target) return ItemStatus.belowTarget;
    final original = originalPrice;
    if ((original != null && original > price) || lastAlertPrice != null) {
      return ItemStatus.onSale;
    }
    return ItemStatus.watching;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'targetPrice': targetPrice,
        'currentPrice': currentPrice,
        'originalPrice': originalPrice,
        'lastChecked': lastChecked?.toIso8601String(),
        'lastError': lastError,
        'lastAlertPrice': lastAlertPrice,
        'history': history.map((p) => p.toJson()).toList(),
        'offers': offers.map((o) => o.toJson()).toList(),
      };

  factory TrackedItem.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    final currentPrice = _toDouble(json['currentPrice']);
    final originalPrice = _toDouble(json['originalPrice']);
    final lastChecked = _toDate(json['lastChecked']);
    final lastError = json['lastError'] as String?;
    final savedOffers = json['offers'] as List?;
    return TrackedItem(
      id: json['id'] as String,
      name: json['name'] as String,
      url: url,
      targetPrice: _toDouble(json['targetPrice']),
      currentPrice: currentPrice,
      originalPrice: originalPrice,
      lastChecked: lastChecked,
      lastError: lastError,
      lastAlertPrice: _toDouble(json['lastAlertPrice']),
      history: ((json['history'] as List?) ?? [])
          .map((e) => PricePoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // Items saved before multi-store support had a single link.
      offers: savedOffers == null
          ? [
              Offer(
                url: url,
                price: currentPrice,
                originalPrice: originalPrice,
                lastChecked: lastChecked,
                lastError: lastError,
              ),
            ]
          : savedOffers.map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class AlertEntry {
  final String id;
  final String itemId;
  final String message;
  final DateTime at;
  bool read;

  AlertEntry({
    required this.id,
    required this.itemId,
    required this.message,
    required this.at,
    this.read = false,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'itemId': itemId, 'message': message, 'at': at.toIso8601String(), 'read': read};

  factory AlertEntry.fromJson(Map<String, dynamic> json) => AlertEntry(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        message: json['message'] as String,
        at: DateTime.parse(json['at'] as String),
        read: json['read'] as bool? ?? false,
      );
}
