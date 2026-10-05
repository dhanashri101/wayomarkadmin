import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';
import '../../widgets/state_views.dart';
import '../assessments/assessments_screen.dart';
import '../bank_offers/create_bank_offer_screen.dart';
import '../consultations/consultations_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../notifications/send_notification_screen.dart';
import '../users/users_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.controller});
  final AdminController controller;

  static const _labels = [
    'Dashboard',
    'Users',
    'Assessments',
    'Consultations',
    'Notify Users',
    'Bank Offer',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pages = <Widget>[
          DashboardScreen(controller: controller),
          UsersScreen(controller: controller),
          AssessmentsScreen(controller: controller),
          ConsultationsScreen(controller: controller),
          SendNotificationScreen(controller: controller),
          CreateBankOfferScreen(controller: controller),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = Column(
              children: [
                if (controller.error != null && controller.error!.isNotEmpty)
                  ErrorBanner(message: controller.error!),
                Expanded(
                  child: IndexedStack(
                    index: controller.selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  wide
                      ? 'Wayomark Admin'
                      : _labels[controller.selectedIndex],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: controller.loading
                        ? null
                        : () => controller.refreshCurrent(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: controller.loading ? null : controller.logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: wide ? const Text('Logout') : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      backgroundColor: Colors.white,
                      selectedIndex: controller.selectedIndex,
                      onDestinationSelected: controller.select,
                      extended: constraints.maxWidth >= 1180,
                      minExtendedWidth: 220,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AdminTheme.primary,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline_rounded),
                          selectedIcon: Icon(Icons.people_rounded),
                          label: Text('Users'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment_rounded),
                          label: Text('Assessments'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.event_available_outlined),
                          selectedIcon: Icon(Icons.event_available_rounded),
                          label: Text('Consultations'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.campaign_outlined),
                          selectedIcon: Icon(Icons.campaign_rounded),
                          label: Text('Notify Users'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.account_balance_outlined),
                          selectedIcon: Icon(Icons.account_balance_rounded),
                          label: Text('Bank Offer'),
                        ),
                      ],
                    ),
                  if (wide)
                    const VerticalDivider(width: 1, color: AdminTheme.border),
                  Expanded(child: content),
                ],
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: controller.selectedIndex,
                      onDestinationSelected: controller.select,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.people_outline_rounded),
                          selectedIcon: Icon(Icons.people_rounded),
                          label: 'Users',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment_rounded),
                          label: 'Assess',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.event_available_outlined),
                          selectedIcon: Icon(Icons.event_available_rounded),
                          label: 'Consult',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.campaign_outlined),
                          selectedIcon: Icon(Icons.campaign_rounded),
                          label: 'Notify',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.account_balance_outlined),
                          selectedIcon: Icon(Icons.account_balance_rounded),
                          label: 'Offer',
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
