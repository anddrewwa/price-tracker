import 'package:flutter/material.dart';

import '../logic/demo_store.dart';
import '../logic/format.dart';
import '../logic/scraper.dart';
import '../services/storage.dart';
import '../widgets.dart';

/// Change demo product prices at each demo shop to simulate a sale during a presentation.
class DemoStoreScreen extends StatefulWidget {
  const DemoStoreScreen({super.key});

  @override
  State<DemoStoreScreen> createState() => _DemoStoreScreenState();
}

class _DemoStoreScreenState extends State<DemoStoreScreen> {
  final _controllers = {
    for (final p in demoProducts)
      for (final s in demoShops) demoKey(p, s): TextEditingController(),
  };
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prices = await Store.demoPrices();
    if (!mounted) return;
    setState(() {
      for (final entry in _controllers.entries) {
        entry.value.text = prices[entry.key]!.toStringAsFixed(2);
      }
      _loaded = true;
    });
  }

  Future<void> _save(DemoProduct product, DemoShop shop) async {
    final price = parsePrice(_controllers[demoKey(product, shop)]!.text);
    if (price == null) {
      _snack('Enter a positive number');
      return;
    }
    await Store.setDemoPrice(demoKey(product, shop), price);
    FocusManager.instance.primaryFocus?.unfocus();
    _snack('${product.name.split(' (').first} is now ${money(price)} at ${shop.name}. '
        'Go back and pull down to check prices.');
  }

  Future<void> _reset() async {
    await Store.resetDemoPrices();
    await _load();
    _snack('Prices reset');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Store'),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Track a demo product (the chips on the "Track item" sheet), use "Find on other '
                  'sites" to add the other demo shops, then lower a price here to simulate a sale.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (final product in demoProducts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProductAvatar(name: product.name, color: theme.colorScheme.primary, size: 40),
                              const SizedBox(width: 12),
                              Expanded(child: Text(product.name, style: theme.textTheme.titleSmall)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final shop in demoShops) _shopRow(theme, product, shop),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _shopRow(ThemeData theme, DemoProduct product, DemoShop shop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          StoreBadge(shop.name, size: 32),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('reg. ${money(demoRegular(product, shop))}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controllers[demoKey(product, shop)],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '\$ ', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _save(product, shop),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
