import 'package:flutter/material.dart';
import '../settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // For now, redirect to Settings screen
    // Later this can be a dedicated "More" screen with additional options
    return const SettingsScreen();
  }
}

