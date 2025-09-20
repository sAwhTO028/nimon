import 'package:flutter/material.dart';
import '../../models/story.dart';
import '../quiz/quiz_screen.dart';

class LearnHubScreen extends StatelessWidget {
  final Story story;
  const LearnHubScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, VoidCallback onTap) => Card(
      child: ListTile(
        leading: const Icon(Icons.text_fields),
        title: Text(title),
        onTap: onTap,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tile('VOCABULARY / KANJI', () {}),
          tile('CONVERSATION', () {}),
          tile('GRAMMAR', () {}),
          const SizedBox(height: 8),
          const Divider(),
          tile('QUIZ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen()))),
          tile('Flashcards', () {}),
          tile('Listening', () {}),
        ],
      ),
    );
  }
}
