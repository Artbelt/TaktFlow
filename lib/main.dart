import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'database/app_database.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  runApp(const TaktFlowApp());
}

class TaktFlowApp extends StatelessWidget {
  const TaktFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Хронометраж операций',
      theme: buildIndustrialTheme(),
      home: const HomeShell(),
    );
  }
}
