import 'package:flutter/material.dart';

class LearnHubScreen extends StatelessWidget {
  const LearnHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Vocabulary/Kanji', Icons.font_download_outlined),
      ('Conversation', Icons.record_voice_over_outlined),
      ('Grammar', Icons.rule_folder_outlined),
      ('Practice', Icons.quiz_outlined),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Learn Hub')),
      body: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        children: [
          for (final t in tiles)
            Card(
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t.$1} (UI-only)'))),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.$2, size: 36), const SizedBox(height: 8), Text(t.$1),
                ])),
              ),
            )
        ],
      ),
    );
  }
}
