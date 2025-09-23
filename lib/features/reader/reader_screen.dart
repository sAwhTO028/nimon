import 'package:flutter/material.dart';
import 'package:nimon/models/story.dart';

/// Clean reader (Narration / Dialog / Monologue / Emotion only)
/// Example item:
///  {'kind':'dialog','text':'遅れそう！','speaker':'AYA','pos':'right','color':'pink'}
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Episode ${episode.index}')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: episode.blocks.length,
        itemBuilder: (ctx, i) => _tile(ctx, episode.blocks[i], i),
      ),
    );
  }

  Widget _tile(BuildContext ctx, EpisodeBlock block, int index) {
    final isDialog = block.type == BlockType.dialog;
    final text = block.text;
    final spk = block.speaker ?? '';
    final pos = (index % 2 == 0) ? 'left' : 'right';
    final color = (index % 3 == 0)
        ? 'blue'
        : (index % 3 == 1)
            ? 'pink'
            : 'green';

    final align = switch (pos) {
      'right' => MainAxisAlignment.end,
      'mid'   => MainAxisAlignment.center,
      _       => MainAxisAlignment.start,
    };
    final bubbleColor = switch (color) {
      'pink'  => Colors.pink.shade100,
      'green' => Colors.green.shade100,
      _       => Colors.blue.shade100,
    };
    Widget content = isDialog
        ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spk.isNotEmpty)
            Text('$spk:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(text),
        ],
      )
        : Text(text);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(ctx).width * (isDialog ? 0.85 : 0.95)),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDialog ? bubbleColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: content,
    );

    return Row(mainAxisAlignment: align, children: [bubble]);
  }
}
