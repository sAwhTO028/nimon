import 'package:flutter/material.dart';
import 'app/app_shell.dart';

void main() => runApp(const NimonApp());

class NimonApp extends StatelessWidget {
  const NimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIMON',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AppShell(),
    );
  }
}
