import 'package:flutter/material.dart';

/// Clean reader (Narration / Dialog / Monologue / Emotion only)
/// Example item:
///  {'kind':'dialog','text':'遅れそう！','speaker':'AYA','pos':'right','color':'pink'}
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.title, required this.blocks});
  final String title;
  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: blocks.length,
        itemBuilder: (ctx, i) => _tile(ctx, blocks[i]),
      ),
    );
  }

  Widget _tile(BuildContext ctx, Map<String, dynamic> b) {
    final kind  = b['kind']   as String? ?? 'narr';
    final text  = b['text']   as String? ?? '';
    final spk   = b['speaker']as String? ?? '';
    final pos   = b['pos']    as String? ?? 'left';
    final color = b['color']  as String? ?? 'blue';

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
    final isDialog = kind == 'dialog';

    Widget content = switch (kind) {
      'dialog' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spk.isNotEmpty)
            Text('$spk:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(text),
        ],
      ),
      'monologue' => Text('『$text』', style: const TextStyle(fontStyle: FontStyle.italic)),
      'emotion'   => Text(text),
      _           => Text(text), // narration
    };

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
