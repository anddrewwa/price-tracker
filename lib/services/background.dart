/// Periodic price checks while the app is closed (Android).
///
/// Android runs this roughly every 30 minutes (15 is the minimum it allows,
/// and it may delay checks to save battery). iOS needs extra Xcode setup for
/// background work, so on iOS prices are checked when you open the app or
/// pull to refresh.
library;

import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import 'notifier.dart';
import 'price_service.dart';

const checkTaskName = 'price-check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      await Notifier.init();
      await PriceService.checkAll();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> setupBackgroundChecks() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    checkTaskName,
    checkTaskName,
    frequency: const Duration(minutes: 30),
  );
}
