import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/episode.dart';
import 'package:nimon/models/story.dart';
import '../writer/writer_screen.dart';
import '../quiz/quiz_screen.dart';

class StoryScreen extends StatefulWidget {
  final Story story;
  const StoryScreen({super.key, required this.story});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final repo = StoryRepoMock();
  late Future<List<Episode>> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.getEpisodesByStory(widget.story.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final eps = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(s.desc, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              for (final e in eps) _EpisodeBubble(ep: e),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => WriterScreen(storyId: s.id, nextOrder: eps.length+1)));
                      setState(()=> _future = repo.getEpisodesByStory(s.id));
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Write Next Episode'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: (){
                      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(storyId: s.id)));
                    },
                    icon: const Icon(Icons.quiz),
                    label: const Text('Learn / Quiz'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeBubble extends StatelessWidget {
  final Episode ep;
  const _EpisodeBubble({required this.ep});

  @override
  Widget build(BuildContext context) {
    final isDialog = ep.type == 'dialog';
    final bg = isDialog ? Colors.blue.shade50 : Colors.grey.shade200;
    final align = isDialog ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final speaker = (ep.speaker ?? '').isEmpty ? '' : '${ep.speaker}: ';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: align, children: [
        if (speaker.isNotEmpty)
          Text(speaker, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(ep.text),
      ]),
    );
  }
}
