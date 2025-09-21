import 'package:flutter/material.dart';
import '../../data/story_repo_mock.dart';

class MonoScreen extends StatelessWidget {
  const MonoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = StoryRepoMock();
    return Scaffold(
      appBar: AppBar(title: const Text('Mono')),
      body: FutureBuilder(
        future: repo.getStories(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final list = (s.data as List).cast<Map<String, dynamic>>();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (c, i) => _MonoCard(data: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Add MONO (UI-only)'))),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MonoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MonoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final level = data['level'] ?? 'N?';
    final title = data['title'] ?? 'Untitled';
    final desc  = data['description'] ?? 'Description overall…';
    final eps   = data['episodes'] ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // thumbnail circle
          Container(
            width: 84, height: 84,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE0E0E0)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                _LevelBadge(level: level),
              ]),
              const SizedBox(height: 6),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Episode - ${eps.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.labelLarge),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Edit Mono (UI-only)'))),
                  icon: const Icon(Icons.edit_note_rounded),
                )
              ])
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});
  @override
  Widget build(BuildContext context) {
    final color = switch (level) { 'N5' => Colors.lightGreen, 'N4' => Colors.cyan, 'N3' => Colors.deepOrange, _ => Colors.grey };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(level, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
    );
  }
}
