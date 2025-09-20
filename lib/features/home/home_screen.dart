import 'package:flutter/material.dart';
import '../../models/story.dart';
import '../story/story_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _chip;
  final _chips = const ['Love', 'History', 'Comedy', 'Horror', 'Art'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NIMON'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              onPressed: () {},
              child: const Row(children: [Icon(Icons.monetization_on, size: 18), SizedBox(width: 6), Text('98')]),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          // category chips (single select)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _chips
                  .map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: _chip == c,
                  onSelected: (_) => setState(() => _chip = _chip == c ? null : c),
                ),
              ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          Text('Recommend Stories', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text("Popular's Stories and Timeline", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // list of stories
          ...demoStories.map(
                (s) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.black12,
                  child: Text(s.level),
                ),
                title: Text(s.title),
                subtitle: Text(s.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.favorite_border),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoryScreen(story: s)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
