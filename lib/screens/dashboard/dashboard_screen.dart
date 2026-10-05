import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/api_data.dart';
import '../../widgets/admin_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final raw = ApiData.unwrap(controller.dashboardRaw);
    final map = ApiData.map(raw);
    final metrics = <MapEntry<String, dynamic>>[];
    final details = <MapEntry<String, dynamic>>[];

    for (final entry in map.entries) {
      if (entry.value is num) {
        metrics.add(entry);
      } else if (entry.value is String || entry.value is bool) {
        details.add(entry);
      }
    }

    return RefreshIndicator(
      onRefresh: controller.loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AdminTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live data from /v1/admin/dashboard',
            style: TextStyle(color: AdminTheme.muted),
          ),
          const SizedBox(height: 20),
          if (controller.loading && map.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (map.isEmpty)
            const AdminCard(
              child: Text(
                'The dashboard API returned no dashboard fields. Use Refresh to try again.',
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final count = width >= 1100 ? 4 : width >= 650 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: count == 1 ? 3.4 : 2.3,
                  ),
                  itemBuilder: (_, index) {
                    final entry = metrics[index];
                    return _MetricCard(
                      title: _prettyKey(entry.key),
                      value: '${entry.value}',
                    );
                  },
                );
              },
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 18),
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _prettyKey(entry.key),
                                style: const TextStyle(color: AdminTheme.muted),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                '${entry.value}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _prettyKey(String value) {
    final spaced = value
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return spaced.isEmpty
        ? value
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(color: AdminTheme.muted)),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AdminTheme.navy,
              ),
            ),
          ],
        ),
      );
}
