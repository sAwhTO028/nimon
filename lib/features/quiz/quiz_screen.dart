import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/quiz_item.dart';

class QuizScreen extends StatefulWidget {
  final String storyId;
  const QuizScreen({super.key, required this.storyId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final repo = StoryRepoMock();
  late Future<List<QuizItem>> _future;
  int _index = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _future = repo.getQuizByStory(widget.storyId);
  }

  void _next(bool correct) {
    if (correct) _score += 5;
    setState(()=> _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (_index >= items.length) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Done! Score: $_score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('XP + $_score (demo)'),
            ]));
          }
          final q = items[_index];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Q${_index+1}/${items.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(q.question, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              if (q.type=='mcq')
                ...List.generate(q.choices!.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: OutlinedButton(
                    onPressed: ()=>_next(i==q.answerIndex),
                    child: Align(alignment: Alignment.centerLeft, child: Text(q.choices![i])),
                  ),
                )),
              if (q.type=='fill') _Fill(q: q, onSubmit: (ok)=>_next(ok)),
            ]),
          );
        },
      ),
    );
  }
}

class _Fill extends StatefulWidget {
  final QuizItem q;
  final void Function(bool) onSubmit;
  const _Fill({required this.q, required this.onSubmit});
  @override
  State<_Fill> createState() => _FillState();
}

class _FillState extends State<_Fill> {
  final c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type answer'),),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: (){
        widget.onSubmit(c.text.trim()==(widget.q.answer??'').trim());
      }, child: const Text('Submit')),
    ]);
  }
}
