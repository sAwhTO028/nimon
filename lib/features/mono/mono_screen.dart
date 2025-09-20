// lib/features/mono/mono_screen.dart
import 'package:flutter/material.dart';
import 'start_mono_sheet.dart';

class MonoScreen extends StatelessWidget {
  const MonoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NIMON')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: List.generate(
          4,
              (i) => Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.black12),
              title: Text(i.isEven ? 'RAINY KYOTO' : 'MORNING AT'),
              subtitle: const Text('Description overall…'),
              trailing: Chip(label: Text(i.isEven ? 'N5' : 'N3')),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const StartMonoSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }
}
