import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';

class HomeScreen extends StatefulWidget {
  final StoryRepo repo;
  const HomeScreen({super.key, required this.repo});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _chip;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NIMON', style: Theme.of(context).textTheme.headlineMedium),
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.monetization_on),
                label: const Text('98'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _chips(),
          const SizedBox(height: 16),
          _shelf('Recommended Stories'),
          const SizedBox(height: 24),
          _shelf('Popular\'s Stories and Timeline'),
          const SizedBox(height: 12),
          FutureBuilder<List<Story>>(
            future: widget.repo.getStories(level: _chip),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <Story>[];
              return Column(
                children: data
                    .take(12)
                    .map((s) => _storyTile(context, s))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chips() {
    final lv = ['N5', 'N4', 'N3', 'N2', 'N1'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: lv
            .map((e) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(e),
            selected: _chip == e,
            onSelected: (_) => setState(() => _chip = _chip == e ? null : e),
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _shelf(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: FutureBuilder<List<Story>>(
            future: widget.repo.getStories(level: _chip),
            builder: (context, snap) {
              final list = snap.data ?? const <Story>[];
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length.clamp(0, 20),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _thumbCard(context, list[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _thumbCard(BuildContext ctx, Story s) {
    return GestureDetector(
      onTap: () => ctx.push('/story/${s.id}'),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(s.coverUrl ?? '', fit: BoxFit.cover),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black45,
                  child: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _storyTile(BuildContext ctx, Story s) {
    return Card(
      child: ListTile(
        onTap: () => ctx.push('/story/${s.id}'),
        leading: CircleAvatar(backgroundImage: NetworkImage(s.coverUrl ?? '')),
        title: Text(s.title),
        subtitle: Text(s.description),
        trailing: const Icon(Icons.favorite_border),
      ),
    );
  }
}
