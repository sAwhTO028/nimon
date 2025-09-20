import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setting')),
      body: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Setting (blank for now)'),
          ),
        ),
      ),
    );
  }
}
