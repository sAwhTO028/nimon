import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/story.dart';

class StoryDetailArgs {
  final String storyId;
  StoryDetailArgs(this.storyId);
}

class StoryDetailScreen extends StatefulWidget {
  static const routeName = '/storyDetail';
  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _repo = StoryRepoMock();

  late Future<Story?> _fStory;
  late Future<List<Episode>> _fEpisodes;

  @override
  void initState() {
    super.initState();
    _fStory = _repo.getStoryById(widget.storyId);
    _fEpisodes = _repo.listEpisodes(widget.storyId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: FutureBuilder(
        future: Future.wait([_fStory, _fEpisodes]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final story = snap.data![0] as Story?;
          final eps = snap.data![1] as List<Episode>;
          final dyn = story as dynamic;
          final desc = (dyn.description as String?) ??
              (dyn.desc as String?) ??
              (dyn.summary as String?) ??
              (dyn.overview as String?) ??
              '';

          if (story == null) {
            return const Center(child: Text('Story not found (mock)'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(story.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text('Level ${story.level}'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('${eps.length} eps'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(desc.isEmpty ? '—' : desc),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(eps.length, (i) {
                return Card(
                  child: ListTile(
                    title: Text('Episode ${i + 1}'),
                    subtitle: const Text('Tap to open (UI-only)'),
                    trailing:
                    const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
