import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/background.dart';
import 'services/notifier.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await setupBackgroundChecks();
    } catch (e) {
      debugPrint('Background checks unavailable: $e');
    }
  }
  runApp(const PriceTrackerApp());
}

class PriceTrackerApp extends StatelessWidget {
  const PriceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Price Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
