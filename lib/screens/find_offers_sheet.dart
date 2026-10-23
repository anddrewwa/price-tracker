import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/search.dart';
import '../models.dart';
import '../services/price_service.dart';
import '../widgets.dart';

/// Searches other stores for an item and lets the user add the matches.
class FindOffersSheet extends StatefulWidget {
  final TrackedItem item;

  const FindOffersSheet({super.key, required this.item});

  @override
  State<FindOffersSheet> createState() => _FindOffersSheetState();
}

class _FindOffersSheetState extends State<FindOffersSheet> {
  List<SearchResult>? _results;
  final _added = <String>{};
  final _adding = <String>{};

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _results = null);
    final results = await PriceService.findOffers(widget.item);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _add(SearchResult result) async {
    setState(() => _adding.add(result.url));
    await PriceService.addOffer(widget.item.id, result.url);
    if (!mounted) return;
    setState(() {
      _adding.remove(result.url);
      _added.add(result.url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = _results;
    final current = widget.item.currentPrice;
    final searched = widget.item.isDemo ? 'the demo stores' : searchSites.map((s) => s.store).join(' and ');

    return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.travel_explore_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compare prices', style: theme.textTheme.titleLarge),
                        Text('Searching $searched',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (results == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Looking for the best price…', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                )
              else if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: scheme.outline),
                      const SizedBox(height: 10),
                      Text('No matches found', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Some stores block automatic searches. You can still paste a link '
                        'from any store with "Add store link".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _search,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Search again'),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _resultTile(theme, results[i], current),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _resultTile(ThemeData theme, SearchResult result, double? current) {
    final scheme = theme.colorScheme;
    final cheaper = current != null && result.price < current;
    final added = _added.contains(result.url);
    final adding = _adding.contains(result.url);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cheaper ? dealColor.withAlpha(14) : scheme.surfaceContainerHighest.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: cheaper ? Border.all(color: dealColor.withAlpha(120), width: 1.5) : null,
      ),
      child: Row(
        children: [
          StoreBadge(result.store),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.store, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(money(result.price),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (cheaper) ...[
                      const SizedBox(width: 8),
                      Text('${money(current - result.price)} less',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: dealColor, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          added
              ? const Icon(Icons.check_circle_rounded, color: dealColor)
              : FilledButton.tonal(
                  onPressed: adding ? null : () => _add(result),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: adding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
        ],
      ),
    );
  }
}
