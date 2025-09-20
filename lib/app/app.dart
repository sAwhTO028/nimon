import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'nav_shell.dart';

class NimonApp extends StatelessWidget {
  const NimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIMON',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    );
  }
}
