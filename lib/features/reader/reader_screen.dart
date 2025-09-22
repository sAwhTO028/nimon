import 'package:flutter/material.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.title, required this.blocks});
  final String title;
  /// blocks: list of map { kind: 'narr|dialog|monologue|action|emotion|choice',
  ///                       text: '...', speaker: '...', pos: 'left/right/mid',
  ///                       color: 'blue/pink/green', options: [..] }
  final List<Map<String, dynamic>> blocks;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String? _choicePicked; // demo only

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: widget.blocks.length,
        itemBuilder: (ctx, i) => _renderBlock(ctx, widget.blocks[i]),
      ),
    );
  }

  Widget _renderBlock(BuildContext ctx, Map<String, dynamic> b) {
    final kind = b['kind'] as String? ?? 'narr';
    final pos  = b['pos']  as String? ?? 'left';
    final color= (b['color'] as String?) ?? 'blue';
    final text = b['text'] as String? ?? '';
    final spk  = b['speaker'] as String? ?? '';
    final options = (b['options'] as List?)?.cast<String>() ?? const <String>[];

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

    Widget content;
    switch (kind) {
      case 'dialog':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spk.isNotEmpty)
              Text('$spk:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            _jlptRich(text),
          ],
        );
        break;
      case 'monologue':
        content = _jlptRich('『$text』');
        break;
      case 'action':
        content = Text('[$text]', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54));
        break;
      case 'emotion':
        content = _jlptRich(text); // assume emoji included at start if you want
        break;
      case 'choice':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('? $text', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: options.map((o) {
                final picked = _choicePicked == o;
                return ChoiceChip(
                  label: Text(o),
                  selected: picked,
                  onSelected: (_)=> setState(()=>_choicePicked=o),
                );
              }).toList(),
            ),
          ],
        );
        break;
      default:
        content = _jlptRich(text);
    }

    final isDialog = kind=='dialog';
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

  // Inline JLPT popup: format 【漢字|かな|meaning】
  Widget _jlptRich(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'【([^|]+)\|([^|]+)\|([^】]+)】');
    int idx = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: text.substring(idx, m.start)));
      }
      final kanji = m.group(1)!;
      final kana  = m.group(2)!;
      final mean  = m.group(3)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InkWell(
          onTap: ()=> _showVocab(kanji, kana, mean),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(kanji),
          ),
        ),
      ));
      idx = m.end;
    }
    if (idx < text.length) {
      spans.add(TextSpan(text: text.substring(idx)));
    }
    return RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 16), children: spans));
  }

  void _showVocab(String kanji, String kana, String meaning) {
    showModalBottomSheet(
      context: context,
      builder: (_)=> SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kanji, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(kana, style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(meaning),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.school_outlined), label: const Text('Add to Practice')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
