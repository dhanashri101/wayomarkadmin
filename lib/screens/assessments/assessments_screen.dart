import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/api_data.dart';
import '../../widgets/admin_card.dart';
import '../../widgets/state_views.dart';

class AssessmentsScreen extends StatelessWidget {
  const AssessmentsScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.loadAssessments,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Assessments',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminTheme.navy),
            ),
            const SizedBox(height: 4),
            Text('${controller.assessments.length} assessments loaded',
                style: const TextStyle(color: AdminTheme.muted)),
            const SizedBox(height: 18),
            if (controller.assessments.isEmpty)
              const EmptyState(message: 'No assessments returned by the admin API.')
            else
              ...controller.assessments.map((item) {
                final id = ApiData.firstText(item, const ['id', 'assessmentId'], fallback: '—');
                final user = ApiData.firstText(
                  item,
                  const ['userName', 'fullName', 'customerName', 'name'],
                  fallback: 'Customer',
                );
                final reason = ApiData.firstText(item, const ['reasonCode', 'reason', 'purpose']);
                final status = ApiData.firstText(item, const ['status', 'state'], fallback: '—');
                final step = ApiData.firstText(item, const ['step', 'currentStep'], fallback: '—');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$user • Assessment #$id',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _Info(label: 'Reason', value: reason),
                            _Info(label: 'Step', value: step),
                            if (item['createdAt'] != null)
                              _Info(label: 'Created', value: '${item['createdAt']}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AdminTheme.background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      );
}
