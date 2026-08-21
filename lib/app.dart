import 'package:flutter/material.dart';

import 'core/session/auth_gate.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';

class ApexBooksApp extends StatefulWidget {
  const ApexBooksApp({super.key, required this.session});
  final SessionController session;

  @override
  State<ApexBooksApp> createState() => _ApexBooksAppState();
}

class _ApexBooksAppState extends State<ApexBooksApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApexBooks',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AuthGate(
        session: widget.session,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
