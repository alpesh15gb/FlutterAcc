import 'package:flutter/material.dart';

import 'app.dart';
import 'core/session/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController();
  await session.initialize();
  runApp(ApexBooksApp(session: session));
}
