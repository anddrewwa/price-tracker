import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models.dart';
import '../services/notifier.dart';
import '../services/price_service.dart';
import '../services/storage.dart';
import '../widgets.dart';
import 'add_item_sheet.dart';
import 'alerts_screen.dart';
import 'demo_store_screen.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<TrackedItem> _items = [];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifier.requestPermission();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Background checks may have run while the app was closed: reload on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final items = await Store.loadItems();
    final alerts = await Store.loadAlerts();
    if (!mounted) return;
    setState(() {
      _items = items;
      _unread = alerts.where((a) => !a.read).length;
      _loading = false;
    });
  }

  Future<void> _checkAll() async {
    await PriceService.checkAll();
    await _load();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  Future<void> _addItem() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddItemSheet(),
    );
    if (added == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _checkAll,
                // A scroll view even when empty so pull-to-refresh still works.
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _header(theme)),
                    if (_items.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _emptyState(theme))
                    else ...[
                      SliverToBoxAdapter(child: _summary(theme)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text('Your items', style: theme.textTheme.titleMedium),
                              const Spacer(),
                              Icon(Icons.swipe_down_alt_rounded, size: 16, color: theme.colorScheme.outline),
                              const SizedBox(width: 4),
                              Text('Pull to refresh',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        sliver: SliverList.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return ItemCard(item: item, onTap: () => _open(ItemDetailScreen(itemId: item.id)));
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Track item'),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    Widget action(String tooltip, Widget icon, VoidCallback onPressed) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton.filledTonal(tooltip: tooltip, icon: icon, onPressed: onPressed),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price Tracker', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text('Get pinged when prices drop',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          action('Demo store', const Icon(Icons.storefront_outlined), () => _open(const DemoStoreScreen())),
          action(
            'Alerts',
            Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            () => _open(const AlertsScreen()),
          ),
        ],
      ),
    );
  }

  /// Gradient card with item count, live deals and total savings.
  Widget _summary(ThemeData theme) {
    final scheme = theme.colorScheme;
    final deals = _items
        .where((i) => i.status == ItemStatus.belowTarget || i.status == ItemStatus.onSale)
        .length;
    var savings = 0.0;
    for (final item in _items) {
      final current = item.currentPrice;
      final original = item.originalPrice;
      if (current != null && original != null && original > current) savings += original - current;
    }
    const onCard = Colors.white;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: theme.textTheme.headlineSmall?.copyWith(color: onCard, fontWeight: FontWeight.w800)),
              ),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: onCard.withAlpha(210))),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.7)!],
        ),
        boxShadow: [
          BoxShadow(color: scheme.primary.withAlpha(60), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: onCard, size: 20),
              const SizedBox(width: 8),
              Text('Overview',
                  style: theme.textTheme.titleSmall?.copyWith(color: onCard, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('${_items.length}', _items.length == 1 ? 'item tracked' : 'items tracked'),
              stat('$deals', deals == 1 ? 'deal now' : 'deals now'),
              stat(money(savings), 'in savings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
              ),
            ),
            child: Icon(Icons.sell_rounded, size: 52, color: scheme.primary),
          ),
          const SizedBox(height: 24),
          Text('Nothing tracked yet', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add a product link and an optional target price. You\'ll get a notification '
            'when it goes on sale or drops below your target.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Track your first item'),
          ),
        ],
      ),
    );
  }
}
