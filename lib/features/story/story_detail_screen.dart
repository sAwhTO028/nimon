import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: FutureBuilder<Story?>(
        future: _storyF,
        builder: (context, snap) {
          final story = snap.data;
          if (story == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
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
                        onTap: () => context.push('/story/${story.id}/write'),
                      ),
                    ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
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
      FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.bookmark), label: const Text('Save')),
      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload), label: const Text('Upload')),
      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.school), label: const Text('Learn')),
      FilledButton.tonalIcon(
        onPressed: () => ctx.push('/story/${s.id}/write'),
        icon: const Icon(Icons.edit),
        label: const Text('Write Next'),
      ),
    ],
  );
}
