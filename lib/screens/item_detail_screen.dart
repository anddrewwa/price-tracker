import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/format.dart';
import '../logic/scraper.dart';
import '../models.dart';
import '../services/price_service.dart';
import '../services/storage.dart';
import '../widgets.dart';
import 'find_offers_sheet.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  TrackedItem? _item;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await Store.getItem(widget.itemId);
    if (mounted) setState(() => _item = item);
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    await PriceService.checkItem(widget.itemId);
    await _load();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _editTarget() async {
    final item = _item!;
    final controller = TextEditingController(text: item.targetPrice?.toStringAsFixed(2) ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Target price'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            helperText: 'Leave blank for no target',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return; // cancelled
    final text = result.trim();
    final target = text.isEmpty ? null : parsePrice(text);
    if (text.isNotEmpty && target == null) {
      _snack('Enter a positive number');
      return;
    }
    await PriceService.setTarget(item.id, target);
    await _load();
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop tracking?'),
        content: Text(_item!.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await Store.deleteItem(widget.itemId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openPage(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) _snack("Couldn't open the link");
  }

  Future<void> _findOffers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FindOffersSheet(item: _item!),
    );
    await _load();
  }

  Future<void> _addLink() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add store link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://store.com/product/...',
            prefixIcon: Icon(Icons.link_rounded),
            helperText: 'The same product at another store',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https', 'demo'].contains(uri.scheme) || uri.host.isEmpty) {
      _snack('Enter a full link starting with https://');
      return;
    }
    setState(() => _checking = true);
    await PriceService.addOffer(widget.itemId, url);
    await _load();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _removeOffer(Offer offer) async {
    await PriceService.removeOffer(widget.itemId, offer.url);
    await _load();
    _snack('Stopped checking ${offer.store}');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final current = item.currentPrice;
    final original = item.originalPrice;
    final target = item.targetPrice;
    final accent = statusColor(context, item.status);
    final best = item.bestOffer;
    final prices = item.history.map((p) => p.price).toList();
    // Newest first, each paired with the check before it to show the change.
    final recent = [
      for (var i = item.history.length - 1; i >= 0 && i >= item.history.length - 20; i--)
        (item.history[i], i > 0 ? item.history[i - 1].price : null),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline_rounded), onPressed: _remove),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Hero: product, status and the big price.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductAvatar(name: item.name, color: accent, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: theme.textTheme.titleMedium?.copyWith(height: 1.25)),
                            const SizedBox(height: 8),
                            StatusChip(item.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(current == null ? '--' : money(current),
                          style: theme.textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                      if (original != null && current != null) ...[
                        Text(money(original),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: muted, decoration: TextDecoration.lineThrough)),
                        SavingsBadge(current: current, original: original),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (best != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, size: 14, color: muted),
                            const SizedBox(width: 4),
                            Text(item.offers.length > 1 ? 'Best price at ${best.store}' : best.store,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: muted),
                          const SizedBox(width: 4),
                          Text('Checked ${timeAgo(item.lastChecked)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ],
                      ),
                    ],
                  ),
                  if (item.lastError != null) ...[
                    const SizedBox(height: 10),
                    Text(item.lastError!, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Lowest',
                  value: prices.isEmpty ? '--' : money(prices.reduce(min)),
                  icon: Icons.south_rounded,
                  color: dealColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Highest',
                  value: prices.isEmpty ? '--' : money(prices.reduce(max)),
                  icon: Icons.north_rounded,
                  color: saleColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Target',
                  value: target == null ? 'None' : money(target),
                  icon: Icons.flag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _checking ? null : _checkNow,
                  icon: _checking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Check now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editTarget,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(target == null ? 'Set target' : 'Edit target'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _storesCard(theme, item),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price history', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  if (item.history.length < 2)
                    Container(
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.show_chart_rounded, color: scheme.outline, size: 32),
                          const SizedBox(height: 6),
                          Text('The chart appears after the second check.',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: Sparkline(values: prices, target: target, strokeWidth: 3, color: accent),
                    ),
                  if (target != null && item.history.length >= 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Container(width: 14, height: 2, color: dealColor),
                          const SizedBox(width: 6),
                          Text('Your target', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ],
                      ),
                    ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    for (final (point, previous) in recent) _historyRow(theme, point, previous),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every store being checked, cheapest first, with the best one highlighted.
  Widget _storesCard(ThemeData theme, TrackedItem item) {
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final best = item.bestOffer;
    final offers = [...item.offers]
      ..sort((a, b) => (a.price ?? double.infinity).compareTo(b.price ?? double.infinity));
    final highest = offers.map((o) => o.price).whereType<double>().fold<double?>(
        null, (m, p) => m == null || p > m ? p : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Compare stores', style: theme.textTheme.titleMedium)),
                Text('${offers.length} ${offers.length == 1 ? 'store' : 'stores'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
            if (best != null && highest != null && highest > best.price!) ...[
              const SizedBox(height: 4),
              Text('Save ${money(highest - best.price!)} by buying at ${best.store}',
                  style: theme.textTheme.bodySmall?.copyWith(color: dealColor, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            for (final offer in offers) _offerRow(theme, item, offer, isBest: offer == best && offers.length > 1),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _checking ? null : _findOffers,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Find on other sites'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: _checking ? null : _addLink,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Add store link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerRow(ThemeData theme, TrackedItem item, Offer offer, {required bool isBest}) {
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final price = offer.price;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: isBest ? dealColor.withAlpha(18) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isBest ? Border.all(color: dealColor.withAlpha(110), width: 1.5) : null,
      ),
      child: Row(
        children: [
          StoreBadge(offer.store),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(offer.store,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: dealColor, borderRadius: BorderRadius.circular(6)),
                        child: const Text('BEST',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                Text(
                  offer.lastError ?? 'Checked ${timeAgo(offer.lastChecked)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: offer.lastError != null ? scheme.error : muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price == null ? '--' : money(price),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isBest ? dealColor : null,
                  )),
              if (offer.originalPrice != null)
                Text(money(offer.originalPrice!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, decoration: TextDecoration.lineThrough)),
            ],
          ),
          if (!offer.isDemo || offer.url != item.url)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: muted),
              onSelected: (action) => action == 'open' ? _openPage(offer.url) : _removeOffer(offer),
              itemBuilder: (_) => [
                if (!offer.isDemo) const PopupMenuItem(value: 'open', child: Text('Open page')),
                if (offer.url != item.url) const PopupMenuItem(value: 'remove', child: Text('Remove store')),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _historyRow(ThemeData theme, PricePoint point, double? previous) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final change = previous == null ? 0.0 : point.price - previous;
    final (IconData icon, Color color) = change < 0
        ? (Icons.arrow_downward_rounded, dealColor)
        : change > 0
            ? (Icons.arrow_upward_rounded, saleColor)
            : (Icons.remove_rounded, muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(money(point.price), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (change != 0) ...[
            const SizedBox(width: 8),
            Text('${change < 0 ? '-' : '+'}${money(change.abs())}',
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          Text(shortDateTime(point.at), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}
