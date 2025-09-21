import 'package:flutter/material.dart';

class ReaderScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> blocks; // {type:'narr/dialogMe/dialogYou', text:'...', speaker:'YAMADA'}
  const ReaderScreen({super.key, required this.title, required this.blocks});

  @override
  Widget build(BuildContext context) {
    final controller = PageController();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageView(
        controller: controller,
        children: [
          _ReaderPage(blocks: blocks),
          // demo pagination – future: split by section
          _ReaderPage(blocks: blocks),
        ],
      ),
    );
  }
}

class _ReaderPage extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;
  const _ReaderPage({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final b in blocks) _bubble(context, b),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bubble(BuildContext context, Map<String, dynamic> b) {
    final type = b['type'] as String? ?? 'narr';
    final text = b['text'] as String? ?? '';
    final speaker = b['speaker'] as String?;
    if (type == 'narr') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      );
    }
    final isMe = type == 'dialogMe';
    final color = isMe ? Colors.lightBlue.shade100 : Colors.pink.shade100;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (speaker != null)
            Padding(
              padding: EdgeInsets.only(left: isMe ? 6 : 0, right: isMe ? 0 : 6),
              child: Text(speaker, style: Theme.of(context).textTheme.labelSmall),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width * 0.75).clamp(260, 640)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                  child: Text(text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
