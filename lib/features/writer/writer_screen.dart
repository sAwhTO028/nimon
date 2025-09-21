import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/models/story.dart';
import 'package:uuid/uuid.dart';
import 'package:nimon/data/repo_singleton.dart';

final _uuid = const Uuid();

class WriterScreen extends StatefulWidget {
  final String storyId;
  const WriterScreen({super.key, required this.storyId});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final _blocks = <EpisodeBlock>[
    const EpisodeBlock(type: BlockType.narration, text: 'Intro narration…'),
  ];
  BlockType _type = BlockType.narration;
  final _speaker = TextEditingController();
  final _text = TextEditingController();

  void _snack(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _addBlock() {
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _blocks.add(EpisodeBlock(
        type: _type,
        text: _text.text.trim(),
        speaker: _type == BlockType.dialog ? _speaker.text.trim() : null,
      ));
      _text.clear();
    });
  }

  @override
  void dispose() {
    _speaker.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Episode'),
        actions: [
          IconButton(onPressed: () => _snack(context, 'AI Check (demo)'), icon: const Icon(Icons.check_circle)),
          IconButton(onPressed: () => _snack(context, 'Saved (demo)'), icon: const Icon(Icons.save)),
          IconButton(onPressed: () => _snack(context, 'Preview (demo)'), icon: const Icon(Icons.visibility)),
          IconButton(onPressed: () => _snack(context, 'Upload (demo)'), icon: const Icon(Icons.cloud_upload)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
              itemCount: _blocks.length,
              onReorder: (a, b) {
                setState(() {
                  if (b > a) b -= 1;
                  final item = _blocks.removeAt(a);
                  _blocks.insert(b, item);
                });
              },
              itemBuilder: (ctx, i) => _blockTile(ctx, _blocks[i], i),
            ),
          ),
          _composer(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_blocks.isEmpty) return;
          final ep = Episode(
            id: _uuid.v4(),
            storyId: widget.storyId,
            index: 0, // repo will set next
            blocks: List.of(_blocks),
          );
          await repo.addEpisode(episode: ep);
          if (context.mounted) {
            _snack(context, 'Published (demo).');
            context.pop();
          }
        },
        label: const Text('Publish'),
        icon: const Icon(Icons.upload),
      ),
    );
  }

  Widget _blockTile(BuildContext ctx, EpisodeBlock b, int i) {
    final isNarr = b.type == BlockType.narration;
    return Container(
      key: ValueKey('b$i'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNarr ? Colors.white : (i.isEven ? Colors.blue.shade50 : Colors.pink.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isNarr)
            Text('${b.speaker ?? ''}:',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(b.text),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                  onPressed: () => setState(() => _blocks.removeAt(i)),
                  icon: const Icon(Icons.delete_outline)),
            ],
          )
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<BlockType>(
              segments: const [
                ButtonSegment(value: BlockType.narration, label: Text('Narration')),
                ButtonSegment(value: BlockType.dialog, label: Text('Dialog')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            if (_type == BlockType.dialog) ...[
              const SizedBox(height: 8),
              TextField(controller: _speaker, decoration: const InputDecoration(labelText: 'Speaker')),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Say anything…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(onPressed: _addBlock, icon: const Icon(Icons.add), label: const Text('Add')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: () => setState(_blocks.clear), child: const Text('Clear')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
