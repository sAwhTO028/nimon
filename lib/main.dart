import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const NimonApp());
}

class NimonApp extends StatelessWidget {
  const NimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIMON',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
