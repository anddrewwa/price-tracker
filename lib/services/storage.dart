/// Saves items, alerts and demo prices on the phone with SharedPreferences.
///
/// Background checks run in a separate isolate, so every read calls reload()
/// to pick up changes the other side made.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/demo_store.dart';
import '../models.dart';

class Store {
  static const _itemsKey = 'items';
  static const _alertsKey = 'alerts';
  static const _demoKey = 'demo_prices';
  static const _maxAlerts = 100;

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------- items ----------

  static Future<List<TrackedItem>> loadItems() async {
    final raw = (await _prefs()).getString(_itemsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => TrackedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _saveItems(List<TrackedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<TrackedItem?> getItem(String id) async {
    for (final item in await loadItems()) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Newest items go first.
  static Future<void> addItem(TrackedItem item) async {
    final items = await loadItems();
    items.insert(0, item);
    await _saveItems(items);
  }

  /// Replaces the saved copy. Does nothing if the item was deleted meanwhile.
  static Future<void> updateItem(TrackedItem item) async {
    final items = await loadItems();
    final index = items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    items[index] = item;
    await _saveItems(items);
  }

  static Future<void> deleteItem(String id) async {
    final items = await loadItems();
    items.removeWhere((e) => e.id == id);
    await _saveItems(items);
    final alerts = await loadAlerts();
    alerts.removeWhere((a) => a.itemId == id);
    await _saveAlerts(alerts);
  }

  // ---------- alerts ----------

  static Future<List<AlertEntry>> loadAlerts() async {
    final raw = (await _prefs()).getString(_alertsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AlertEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _saveAlerts(List<AlertEntry> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertsKey, jsonEncode(alerts.map((e) => e.toJson()).toList()));
  }

  static Future<void> addAlert(String itemId, String message) async {
    final alerts = await loadAlerts();
    alerts.insert(0, AlertEntry(id: newId(), itemId: itemId, message: message, at: DateTime.now()));
    if (alerts.length > _maxAlerts) alerts.removeRange(_maxAlerts, alerts.length);
    await _saveAlerts(alerts);
  }

  static Future<void> markAllAlertsRead() async {
    final alerts = await loadAlerts();
    for (final a in alerts) {
      a.read = true;
    }
    await _saveAlerts(alerts);
  }

  static Future<void> clearAlerts() => _saveAlerts([]);

  // ---------- demo store prices ----------

  static Future<Map<String, double>> demoPrices() async {
    final raw = (await _prefs()).getString(_demoKey);
    final saved = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return {
      for (final p in demoProducts)
        for (final s in demoShops)
          demoKey(p, s): (saved[demoKey(p, s)] as num?)?.toDouble() ?? demoRegular(p, s),
    };
  }

  /// [key] is a [demoKey], e.g. "headphones" or "headphones/megamart".
  static Future<void> setDemoPrice(String key, double price) async {
    final prices = await demoPrices();
    prices[key] = price;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_demoKey, jsonEncode(prices));
  }

  static Future<void> resetDemoPrices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoKey);
  }
}
