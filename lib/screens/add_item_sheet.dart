import 'package:flutter/material.dart';

import '../logic/demo_store.dart';
import '../logic/scraper.dart';
import '../services/price_service.dart';
import '../widgets.dart';

/// Bottom sheet for adding a link to track. Pops with `true` when added.
class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key});

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _url = TextEditingController();
  final _target = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _target.dispose();
    super.dispose();
  }

  String? _validate(String url, String target) {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https', 'demo'].contains(uri.scheme) || uri.host.isEmpty) {
      return 'Enter a full link starting with https://';
    }
    if (target.isNotEmpty && parsePrice(target) == null) {
      return 'Target price must be a positive number';
    }
    return null;
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final target = _target.text.trim();
    final error = _validate(url, target);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PriceService.addItem(url, targetPrice: target.isEmpty ? null : parsePrice(target));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
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
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_link_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track an item', style: theme.textTheme.titleLarge),
                    Text('Paste a link and we\'ll watch the price',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Product link',
              hintText: 'https://store.com/product/...',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Alert me at or below (optional)',
              prefixIcon: Icon(Icons.flag_outlined),
              prefixText: '\$ ',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text('Or try a demo product',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in demoProducts)
                ActionChip(
                  avatar: Icon(ProductAvatar.iconFor(p.name), size: 18),
                  label: Text(p.name.split(' (').first),
                  onPressed: () => setState(() => _url.text = p.url),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start tracking'),
            ),
          ),
        ],
      ),
    );
  }
}
