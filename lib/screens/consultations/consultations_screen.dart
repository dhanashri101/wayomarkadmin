import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/api_data.dart';
import '../../widgets/admin_card.dart';
import '../../widgets/state_views.dart';

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: controller.loadConsultations,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Consultations',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminTheme.navy),
            ),
            const SizedBox(height: 4),
            Text('${controller.consultations.length} consultation records loaded',
                style: const TextStyle(color: AdminTheme.muted)),
            const SizedBox(height: 18),
            if (controller.consultations.isEmpty)
              const EmptyState(message: 'No consultations returned by the admin API.')
            else
              ...controller.consultations.map((item) {
                final user = ApiData.firstText(
                  item,
                  const ['userName', 'customerName', 'fullName', 'name'],
                  fallback: 'Customer',
                );
                final expert = ApiData.firstText(item, const ['expertName', 'expert', 'advisorName'], fallback: 'Expert');
                final when = ApiData.firstText(item, const ['scheduledAt', 'date', 'createdAt']);
                final channel = ApiData.firstText(item, const ['channel', 'mode'], fallback: '—');
                final status = ApiData.firstText(item, const ['status', 'state'], fallback: '—');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AdminTheme.primary.withOpacity(.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event_available_rounded, color: AdminTheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$user with $expert', style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text('$when • $channel', style: const TextStyle(color: AdminTheme.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.primary)),
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
