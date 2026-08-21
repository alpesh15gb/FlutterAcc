import 'package:flutter/material.dart';

import '../../features/auth/company_selector_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/two_factor_screen.dart';
import '../../features/shell/app_shell.dart';
import 'session_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.session,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final SessionController session;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return switch (session.stage) {
          SessionStage.loading =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionStage.signedOut => LoginScreen(session: session),
          SessionStage.twoFactor => TwoFactorScreen(session: session),
          SessionStage.companySelection =>
            CompanySelectorScreen(session: session),
          SessionStage.signedIn => AppShell(
              session: session,
              themeMode: themeMode,
              onThemeModeChanged: onThemeModeChanged,
            ),
        };
      },
    );
  }
}
