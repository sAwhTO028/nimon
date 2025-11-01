import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/ui/ui.dart';

class MonoScreen extends StatelessWidget {
  final StoryRepo repo;
  const MonoScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mono'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create'),
            tooltip: 'Create',
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
      body: FutureBuilder<List<Story>>(
        future: repo.getStories(),
        builder: (context, snap) {
          final list = snap.data ?? const <Story>[];
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: list.length.clamp(0, 30),
            itemBuilder: (_, i) => _monoCard(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _monoCard(BuildContext ctx, Story s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 44, backgroundImage: NetworkImage(s.coverUrl ?? '')),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Description overall……', maxLines: 1),
                  const SizedBox(height: 8),
                  Text('Episode – 0${(s.likes % 9) + 1}'),
                ],
              ),
            ),
            Column(
              children: [
                Chip(label: Text(s.jlptLevel)),
                const SizedBox(height: 8),
                const Icon(Icons.edit_note, size: 28),
              ],
            )
          ],
        ),
      ),
    );
  }

}
