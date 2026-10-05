import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/network/wayomark_api.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/api_data.dart';
import '../../widgets/admin_card.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final Set<int> _selected = <int>{};
  bool _sending = false;
  String _type = 'ADMIN';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      _message('Select at least one user.', error: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.controller.sendNotification(
        userIds: _selected.toList(),
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
      );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      setState(_selected.clear);
      _message('Notification sent successfully.');
    } on WayomarkApiException catch (e) {
      _message(e.message, error: true);
    } catch (e) {
      _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AdminTheme.danger : AdminTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.controller.users;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Notify Users',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminTheme.navy),
        ),
        const SizedBox(height: 4),
        const Text('POST /v1/admin/notifications', style: TextStyle(color: AdminTheme.muted)),
        const SizedBox(height: 18),
        AdminCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Notification title'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a message.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                    DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                    DropdownMenuItem(value: 'ALERT', child: Text('ALERT')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'ADMIN'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Recipients', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: users.isEmpty
                          ? null
                          : () => setState(() {
                                _selected
                                  ..clear()
                                  ..addAll(users.map(_userId).whereType<int>());
                              }),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const Divider(),
                if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No users are loaded yet. Refresh the Users tab first.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final id = _userId(user);
                        final name = ApiData.firstText(user, const ['fullName', 'name', 'email'], fallback: 'User');
                        final subtitle = ApiData.firstText(user, const ['email', 'phone'], fallback: id == null ? 'Missing user id' : 'User #$id');
                        return CheckboxListTile(
                          value: id != null && _selected.contains(id),
                          onChanged: id == null
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  }),
                          title: Text(name),
                          subtitle: Text(subtitle),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Sending...' : 'Send notification (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  int? _userId(Map<String, dynamic> user) {
    for (final key in const ['id', 'userId', 'user_id']) {
      final id = ApiData.intValue(user[key]);
      if (id != null) return id;
    }
    return null;
  }
}
