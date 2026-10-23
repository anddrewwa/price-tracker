import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models.dart';
import '../services/storage.dart';
import '../widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertEntry>? _alerts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alerts = await Store.loadAlerts();
    if (mounted) setState(() => _alerts = alerts);
    // Seeing the list counts as reading it (unread ones stay highlighted this visit).
    await Store.markAllAlertsRead();
  }

  Future<void> _clear() async {
    await Store.clearAlerts();
    if (mounted) setState(() => _alerts = []);
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (alerts != null && alerts.isNotEmpty)
            TextButton(onPressed: _clear, child: const Text('Clear all')),
        ],
      ),
      body: alerts == null
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_none_rounded,
                              size: 40, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text('No alerts yet', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Deals on your items will show up here.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final alert = alerts[i];
                    final color = alert.read ? theme.colorScheme.outline : dealColor;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: color.withAlpha(28), shape: BoxShape.circle),
                              child: Icon(Icons.sell_rounded, size: 20, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.message,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: alert.read ? FontWeight.w500 : FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(timeAgo(alert.at),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (!alert.read)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6, left: 8),
                                decoration: const BoxDecoration(color: dealColor, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
