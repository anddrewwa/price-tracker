/// Reusable pieces of UI: the item card, status chip and price sparkline.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'logic/format.dart';
import 'models.dart';

const dealColor = Color(0xFF16A34A);
const saleColor = Color(0xFFE11D48);

/// The accent color for an item's status (green for deals, red for sales).
Color statusColor(BuildContext context, ItemStatus status) => switch (status) {
      ItemStatus.belowTarget => dealColor,
      ItemStatus.onSale => saleColor,
      _ => Theme.of(context).colorScheme.primary,
    };

class StatusChip extends StatelessWidget {
  final ItemStatus status;

  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, IconData icon, Color color) = switch (status) {
      ItemStatus.belowTarget => ('Below target', Icons.check_circle_rounded, dealColor),
      ItemStatus.onSale => ('On sale', Icons.local_fire_department_rounded, saleColor),
      ItemStatus.watching => ('Watching', Icons.visibility_outlined, scheme.onSurfaceVariant),
      ItemStatus.unknown => ('No price yet', Icons.help_outline_rounded, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// "-20%" pill shown when the price is below the store's "was" price.
class SavingsBadge extends StatelessWidget {
  final double current;
  final double original;

  const SavingsBadge({super.key, required this.current, required this.original});

  @override
  Widget build(BuildContext context) {
    final percent = ((original - current) / original * 100).round();
    if (percent <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: saleColor, borderRadius: BorderRadius.circular(6)),
      child: Text('-$percent%',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/// A rounded tile with an icon that hints at what the product is.
class ProductAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const ProductAvatar({super.key, required this.name, required this.color, this.size = 48});

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any(n.contains);
    if (has(['headphone', 'earbud', 'speaker', 'audio'])) return Icons.headphones_rounded;
    if (has(['keyboard'])) return Icons.keyboard_rounded;
    if (has(['ssd', 'drive', 'storage', 'memory', 'ram'])) return Icons.storage_rounded;
    if (has(['phone'])) return Icons.smartphone_rounded;
    if (has(['laptop', 'macbook', 'notebook'])) return Icons.laptop_rounded;
    if (has(['monitor', 'tv', 'display'])) return Icons.tv_rounded;
    if (has(['watch'])) return Icons.watch_rounded;
    if (has(['camera'])) return Icons.photo_camera_rounded;
    if (has(['mouse'])) return Icons.mouse_rounded;
    if (has(['shoe', 'sneaker'])) return Icons.directions_run_rounded;
    if (has(['shirt', 'jacket', 'hoodie', 'dress'])) return Icons.checkroom_rounded;
    if (has(['book'])) return Icons.menu_book_rounded;
    if (has(['game', 'console', 'controller'])) return Icons.sports_esports_rounded;
    return Icons.shopping_bag_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(46), color.withAlpha(20)],
        ),
      ),
      child: Icon(iconFor(name), color: color, size: size * 0.5),
    );
  }
}

/// A colored square with a store's initial, e.g. "A" for Amazon.
class StoreBadge extends StatelessWidget {
  final String store;
  final double size;

  const StoreBadge(this.store, {super.key, this.size = 36});

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF9333EA), Color(0xFFEA580C),
    Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFF65A30D),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[store.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(store.isEmpty ? '?' : store[0].toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.45)),
    );
  }
}

/// A small line chart of the price history, with the target as a dashed line.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final double? target;
  final double strokeWidth;
  final Color? color;

  const Sparkline({super.key, required this.values, this.target, this.strokeWidth = 2, this.color});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      painter: _SparkPainter(
        values: values,
        target: target,
        lineColor: color ?? Theme.of(context).colorScheme.primary,
        targetColor: dealColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final double? target;
  final Color lineColor;
  final Color targetColor;
  final double strokeWidth;

  _SparkPainter({
    required this.values,
    required this.target,
    required this.lineColor,
    required this.targetColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = target;
    final all = [...values, if (t != null) t];
    final low = all.reduce(min);
    final high = all.reduce(max);
    final range = high - low;
    final pad = strokeWidth * 2;
    // A flat history sits in the middle instead of along the bottom.
    double y(double v) =>
        range == 0 ? size.height / 2 : size.height - pad - (v - low) / range * (size.height - 2 * pad);
    double x(int i) => pad + i / (values.length - 1) * (size.width - 2 * pad);

    if (t != null) {
      final paint = Paint()
        ..color = targetColor.withAlpha(180)
        ..strokeWidth = 1.2;
      final ty = y(t);
      for (double dx = 0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset(min(dx + 4, size.width), ty), paint);
      }
    }

    final line = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }

    // Soft gradient under the line.
    final area = Path.from(line)
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withAlpha(70), lineColor.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dot on the latest price.
    final last = Offset(x(values.length - 1), y(values.last));
    canvas.drawCircle(last, strokeWidth * 2, Paint()..color = lineColor);
    canvas.drawCircle(last, strokeWidth * 0.9, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.target != target || old.lineColor != lineColor;
}

class ItemCard extends StatelessWidget {
  final TrackedItem item;
  final VoidCallback onTap;

  const ItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final status = item.status;
    final accent = statusColor(context, status);
    final isDeal = status == ItemStatus.belowTarget || status == ItemStatus.onSale;
    final original = item.originalPrice;
    final current = item.currentPrice;
    final target = item.targetPrice;

    return Card(
      shape: isDeal
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: accent.withAlpha(140), width: 1.5),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductAvatar(name: item.name, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(height: 1.25)),
                        const SizedBox(height: 6),
                        StatusChip(status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(current == null ? '--' : money(current),
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            if (original != null && current != null) ...[
                              Text(money(original),
                                  style: TextStyle(color: muted, decoration: TextDecoration.lineThrough)),
                              SavingsBadge(current: current, original: original),
                            ],
                          ],
                        ),
                        if (item.bestOffer case final best?) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.offers.length > 1
                                ? 'Best at ${best.store} · ${item.offers.length} stores'
                                : 'at ${best.store}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: item.offers.length > 1 ? accent : muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(target == null ? Icons.flag_outlined : Icons.flag_rounded,
                                size: 14, color: target == null ? muted : dealColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${target == null ? 'No target' : money(target)} · ${timeAgo(item.lastChecked)}',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (item.history.length >= 2) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      height: 44,
                      child: Sparkline(
                        values: item.history.map((p) => p.price).toList(),
                        target: target,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
              if (item.lastError != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item.lastError!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled number in a soft box, e.g. "Lowest  $199.99".
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
