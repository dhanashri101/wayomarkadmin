import 'package:flutter/material.dart';

import 'controllers/admin_controller.dart';
import 'core/theme/admin_theme.dart';
import 'screens/login/admin_login_screen.dart';
import 'screens/shell/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AdminController();
  await controller.bootstrap();
  runApp(WayomarkAdminApp(controller: controller));
}

class WayomarkAdminApp extends StatelessWidget {
  const WayomarkAdminApp({super.key, required this.controller});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wayomark Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.data,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.booting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!controller.authenticated) {
            return AdminLoginScreen(controller: controller);
          }
          return AdminShell(controller: controller);
        },
      ),
    );
  }
}
