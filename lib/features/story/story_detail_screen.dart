import 'package:flutter/material.dart';
import '../../data/story_repo_mock.dart';
import '../writer/writer_screen.dart';
import '../learn/learn_hub_screen.dart';
import '../reader/reader_screen.dart';

class StoryDetailScreen extends StatefulWidget {
  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});
  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _repo = StoryRepoMock();
  late Future<dynamic> _fStory;
  late Future<List<dynamic>> _fEpisodes;

  @override
  void initState() {
    super.initState();
    _fStory = _repo.getStoryById(widget.storyId);
    _fEpisodes = _repo.getEpisodesByStory(widget.storyId);
  }

  String _desc(dynamic s){
    return (s['description'] ?? s['desc'] ?? s['summary'] ?? '') as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
        actions: [
          IconButton(icon: const Icon(Icons.save_alt_rounded), onPressed: (){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally (UI-only)')));
          }),
          IconButton(icon: const Icon(Icons.cloud_upload_rounded), onPressed: (){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload → AI check (UI-only)')));
          }),
          IconButton(icon: const Icon(Icons.school_outlined), onPressed: (){
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnHubScreen()));
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_note_rounded),
        onPressed: (){
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => WriterScreen(storyId: widget.storyId)));
        },
        label: const Text('Edit+'),
      ),
      body: FutureBuilder(
        future: Future.wait([_fStory, _fEpisodes]),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data![0] as Map<String,dynamic>?;
          final eps = snap.data![1] as List<dynamic>;
          if (s==null) return const Center(child: Text('Not found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image, size: 48)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['title'] ?? 'Untitled', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            Chip(label: Text('Level ${s['level'] ?? 'N/A'}')),
                            Chip(label: Text('${eps.length} eps')),
                            ...(s['tags'] as List<dynamic>? ?? []).take(3).map((t)=>Chip(label: Text(t.toString()))),
                          ]),
                          const SizedBox(height: 8),
                          Text(_desc(s).isEmpty ? '—' : _desc(s)),
                        ]),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(eps.length, (i){
                final e = eps[i] as Map<String,dynamic>;
                final idx = e['index'] ?? i+1;
                final preview = e['preview'] ?? e['text'] ?? '';
                return Card(
                  child: ListTile(
                    title: Text('Episode $idx'),
                    subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReaderScreen(
                          title: s['title'] ?? 'Episode',
                          blocks: [
                            {'type':'narr','text':'Rain was falling softly…'},
                            {'type':'dialogMe','speaker':'YAMADA','text':'Ah… I forgot my umbrella.'},
                            {'type':'dialogYou','speaker':'AYANA','text':'Do you want to share mine?'},
                            {'type':'narr','text':'Aya tilted her umbrella…'},
                          ],
                        ),
                      ));
                    },
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
