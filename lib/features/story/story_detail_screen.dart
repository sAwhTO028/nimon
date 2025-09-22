import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';

class StoryDetailScreen extends StatefulWidget {
  final StoryRepo repo;
  final String storyId;
  const StoryDetailScreen({super.key, required this.repo, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late Future<Story?> _storyF;
  late Future<List<Episode>> _epsF;

  @override
  void initState() {
    super.initState();
    _storyF = widget.repo.getStoryById(widget.storyId);
    _epsF = widget.repo.getEpisodesByStory(widget.storyId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Story?>(
      future: _storyF,
      builder: (context, snap) {
        final story = snap.data;
        if (story == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Story'),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reacted ♥ (demo)')),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _hero(story),
              const SizedBox(height: 12),
              Text(story.description),
              const SizedBox(height: 16),
              _actions(context, story),
              const SizedBox(height: 12),
              Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<Episode>>(
                future: _epsF,
                builder: (context, s2) {
                  final eps = s2.data ?? const <Episode>[];
                  return Column(
                    children: eps
                        .map((e) => Card(
                      child: ListTile(
                        title: Text('Episode ${e.index}'),
                        subtitle: Text(e.preview),
                        onTap: () => _openReader(context, story, e),
                      ),
                    ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openReader(BuildContext ctx, Story story, Episode ep) {
    // map Episode.blocks -> ReaderScreen blocks format
    final blocks = <Map<String, dynamic>>[];
    for (var i = 0; i < ep.blocks.length; i++) {
      final b = ep.blocks[i];
      if (b.type == BlockType.narration) {
        blocks.add({'type': 'narr', 'text': b.text});
      } else {
        final side = (i % 2 == 0) ? 'dialogMe' : 'dialogYou';
        blocks.add({'type': side, 'text': b.text, 'speaker': b.speaker ?? ''});
      }
    }
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(title: story.title, blocks: blocks),
    ));
  }

  Widget _hero(Story s) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(s.coverUrl ?? '', fit: BoxFit.cover),
          Container(color: Colors.black26),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(s.title,
                  style: const TextStyle(
                      fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    ),
  );

  Widget _actions(BuildContext ctx, Story s) => Wrap(
    spacing: 12,
    children: [
      FilledButton.icon(
        onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Saved (demo)')),
        ),
        icon: const Icon(Icons.bookmark),
        label: const Text('Save'),
      ),
      OutlinedButton.icon(
        onPressed: () => ctx.push('/learn/${s.id}'),
        icon: const Icon(Icons.school),
        label: const Text('Learn'),
      ),
      FilledButton.tonalIcon(
        onPressed: () => ctx.push('/story/${s.id}/write'),
        icon: const Icon(Icons.edit),
        label: const Text('Write Next'),
      ),
    ],
  );
}
