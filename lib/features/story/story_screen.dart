import 'package:flutter/material.dart';
import '../../models/story.dart';
import '../learn/learn_hub_screen.dart';

class StoryScreen extends StatefulWidget {
  final Story story;
  const StoryScreen({super.key, required this.story});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final PageController _page = PageController();

  @override
  Widget build(BuildContext context) {
    final eps = demoEpisodes;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.story.title),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: eps.length,
              itemBuilder: (_, i) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _Narration(eps[i].narration),
                  const SizedBox(height: 8),
                  const _Dialog(speaker: 'YAMADA', text: 'かさ を わすれました。'),
                  const _Dialog(speaker: 'AYANA', text: 'いっしょに いきますか。', right: true),
                  const SizedBox(height: 8),
                  _Narration(eps[i].footer),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '01 / ${eps.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        spacing: 10,
        children: [
          FloatingActionButton.small(
            heroTag: 'save',
            onPressed: () => _toast('Saved locally'),
            child: const Icon(Icons.save_alt),
          ),
          FloatingActionButton.small(
            heroTag: 'upload',
            onPressed: () => _toast('Upload (UI only)'),
            child: const Icon(Icons.cloud_upload),
          ),
          FloatingActionButton.extended(
            heroTag: 'learn',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LearnHubScreen(story: widget.story)),
            ),
            icon: const Icon(Icons.menu_book),
            label: const Text('Learn'),
          ),
        ],
      ),
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _Narration extends StatelessWidget {
  final String text;
  const _Narration(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Text(text),
  );
}

class _Dialog extends StatelessWidget {
  final String speaker, text;
  final bool right;
  const _Dialog({super.key, required this.speaker, required this.text, this.right = false});

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: right ? const Color(0xFFFFE5F4) : const Color(0xFFE1F5FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(speaker, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [SizedBox(width: 240, child: bubble)],
      ),
    );
  }
}
