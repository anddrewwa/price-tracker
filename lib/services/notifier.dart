/// Shows price alerts as phone notifications.
///
/// Every call is wrapped in try/catch: a notification problem should never
/// stop a price check from being saved.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Notifications are only set up for Android and iOS.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (_ready || !supported) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Android 13+ and iOS ask the user before showing notifications.
  static Future<void> requestPermission() async {
    await init();
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  static Future<void> show(String title, String body) async {
    await init();
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'price_alerts',
        'Price alerts',
        channelDescription: 'Sale and target-price alerts for tracked items',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    // Each alert gets its own id so several can show at once.
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
