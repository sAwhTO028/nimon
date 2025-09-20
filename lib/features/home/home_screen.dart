import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/widgets/story_card.dart';
import '../story/story_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = StoryRepoMock();
  late Future<List<Story>> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.getStories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NIMON')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          final stories = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => StoryCard(
              story: stories[i],
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => StoryScreen(story: stories[i])),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){}, label: const Text('New Story'), icon: const Icon(Icons.add),
      ),
    );
  }
}
