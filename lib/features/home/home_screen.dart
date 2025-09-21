import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../data/story_repo_mock.dart';
import '../story/story_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = StoryRepoMock();
  String _selectedLevel = 'All';
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getStories();
  }

  @override
  Widget build(BuildContext context) {
    final pad = R.hPad(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nimon Home'), actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
        PopupMenuButton(itemBuilder: (_) => const [
          PopupMenuItem(value: 'settings', child: Text('Settings')),
        ]),
      ]),
      body: Padding(
        padding: pad,
        child: FutureBuilder(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final stories = (snap.data! as List<dynamic>)
                .where((s)=> _selectedLevel=='All' || (s['level']??'')==_selectedLevel)
                .toList();

            return ListView(
              children: [
                _LevelChips(
                  selected: _selectedLevel,
                  onChanged: (v) => setState(()=>_selectedLevel=v),
                ),
                const SizedBox(height: 12),
                Text('Trending', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _Shelf(stories: stories, onTap: (s){
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StoryDetailScreen(storyId: s['id']),
                  ));
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _LevelChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lvls = const ['All','N5','N4','N3'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_,i) {
          final v = lvls[i];
          final sel = v==selected;
          return ChoiceChip(
            label: Text(v),
            selected: sel,
            showCheckmark: false,
            onSelected: (_) => onChanged(v),
          );
        },
        separatorBuilder: (_,__)=>const SizedBox(width:8),
        itemCount: lvls.length,
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  final List<dynamic> stories;
  final Function(Map<String,dynamic>) onTap;
  const _Shelf({required this.stories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c,i){
          final s = stories[i] as Map<String,dynamic>;
          return GestureDetector(
            onTap: ()=>onTap(s),
            child: AspectRatio(
              aspectRatio: 16/9,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.blueGrey.shade100),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(s['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal:6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text('${s['episodes']} eps', style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
