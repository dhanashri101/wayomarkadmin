import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/theme/admin_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.login(
      identifier: _identifier.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.border),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 30,
                      offset: Offset(0, 10),
                      color: Color(0x12000000),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AdminTheme.primary.withOpacity(.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AdminTheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Wayomark Admin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with an account that has admin API permission.',
                        style: TextStyle(color: AdminTheme.muted),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _identifier,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email / phone / identifier',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter your admin identifier.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) {
                          final error = widget.controller.error;
                          if (error == null || error.isEmpty) {
                            return const SizedBox(height: 20);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              error,
                              style: const TextStyle(color: AdminTheme.danger),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 52,
                        child: AnimatedBuilder(
                          animation: widget.controller,
                          builder: (context, _) => FilledButton.icon(
                            onPressed: widget.controller.loading ? null : _submit,
                            icon: widget.controller.loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              widget.controller.loading
                                  ? 'Signing in...'
                                  : 'Sign in to Admin',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The app verifies admin access by calling /v1/admin/dashboard after login.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
