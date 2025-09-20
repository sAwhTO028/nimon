import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0, score = 0;
  final qs = const [
    {'q': '四千', 'ops': ['よん', 'しはんき', 'よんせん', 'よっつ'], 'a': 2},
  ];

  @override
  Widget build(BuildContext context) {
    final q = qs[i];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 12), child: Text('1/10')))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Center(
              child: Card(
                child: SizedBox(
                  height: 160,
                  width: 220,
                  child: Center(child: Text(q['q'] as String, style: const TextStyle(fontSize: 36))),
                ),
              ),
            ),
          ),
          ...List.generate((q['ops'] as List).length, (idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: () {
                  final ok = idx == (q['a'] as int);
                  if (ok) score += 5;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '✓ Correct! +5 XP' : '✗')),
                  );
                },
                child: Text((q['ops'] as List)[idx]),
              ),
            );
          }),
        ]),
      ),
    );
  }
}
