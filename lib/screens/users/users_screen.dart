import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/api_data.dart';
import '../../widgets/admin_card.dart';
import '../../widgets/state_views.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();
        final users = widget.controller.users.where((item) {
          if (q.isEmpty) return true;
          return item.values.any((v) => '$v'.toLowerCase().contains(q));
        }).toList();

        return RefreshIndicator(
          onRefresh: widget.controller.loadUsers,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Users',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminTheme.navy),
              ),
              const SizedBox(height: 4),
              Text('${widget.controller.users.length} users loaded from the admin API',
                  style: const TextStyle(color: AdminTheme.muted)),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name, email, phone, role...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (users.isEmpty)
                const EmptyState(message: 'No users found.')
              else
                ...users.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AdminTheme.primary.withOpacity(.1),
                              foregroundColor: AdminTheme.primary,
                              child: Text(_initial(item)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ApiData.firstText(item, const ['fullName', 'name', 'username'], fallback: 'User'),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _subtitle(item),
                                    style: const TextStyle(color: AdminTheme.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusChip(text: ApiData.firstText(item, const ['status', 'role'], fallback: 'ACTIVE')),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  String _initial(Map<String, dynamic> item) {
    final name = ApiData.firstText(item, const ['fullName', 'name', 'email'], fallback: 'U').trim();
    return name.isEmpty ? 'U' : name[0].toUpperCase();
  }

  String _subtitle(Map<String, dynamic> item) {
    final email = ApiData.firstText(item, const ['email'], fallback: '');
    final phone = ApiData.firstText(item, const ['phone', 'mobile', 'destination'], fallback: '');
    return [email, phone].where((e) => e.isNotEmpty).join(' • ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AdminTheme.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
