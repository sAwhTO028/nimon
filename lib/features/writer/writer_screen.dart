import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';

enum WriterKind { narration, dialog, monologue, action, emotion, choice }
enum _Pos { left, right, mid }

class _BlockMeta {
  _BlockMeta({
    required this.kind,
    this.pos = _Pos.left,
    this.colorCode = 'blue',
    this.emotion = '🙂',
    this.choiceOptions = const <String>[],
    this.speaker,
  });

  WriterKind kind;
  _Pos pos;
  String colorCode;           // blue | pink | green
  String emotion;            // emoji
  List<String> choiceOptions;
  String? speaker;           // for dialog
}

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key, required this.repo, required this.storyId});
  final StoryRepo repo;
  final String storyId;

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final _textCtl = TextEditingController();
  final _speakerCtl = TextEditingController();

  // Choice option editors
  final _opt1 = TextEditingController();
  final _opt2 = TextEditingController();
  final _opt3 = TextEditingController();

  WriterKind _kind = WriterKind.narration;
  _Pos _pos = _Pos.left;
  String _color = 'blue';
  String _emotion = '🙂';

  final List<EpisodeBlock> _blocks = [];
  final List<_BlockMeta> _metas = [];

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _textCtl.dispose();
    _speakerCtl.dispose();
    _opt1.dispose();
    _opt2.dispose();
    _opt3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Episode'),
        actions: [
          IconButton(icon: const Icon(Icons.psychology_alt_outlined), onPressed: ()=>_snack('AI check (demo)')),
          IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: ()=>_snack('Saved (demo)')),
          IconButton(icon: const Icon(Icons.remove_red_eye_outlined), onPressed: ()=>_snack('Preview (demo)')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _blocks.isEmpty
                ? const Center(child: Text('No content yet. Write something below.'))
                : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _blocks.length,
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n -= 1;
                  final b = _blocks.removeAt(o);
                  final m = _metas.removeAt(o);
                  _blocks.insert(n, b);
                  _metas.insert(n, m);
                });
              },
              itemBuilder: (ctx, i) => _tile(ctx, i, key: ValueKey('b_$i')),
            ),
          ),
          const Divider(height: 1),

          // Kind selector (6)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _seg('Narration', WriterKind.narration),
                _seg('Dialog',    WriterKind.dialog),
                _seg('Monologue', WriterKind.monologue),
                _seg('Action',    WriterKind.action),
                _seg('Emotion',   WriterKind.emotion),
                _seg('Choice',    WriterKind.choice),
              ],
            ),
          ),

          // Kind-specific editors
          if (_kind == WriterKind.dialog) _dialogOptions(),
          if (_kind == WriterKind.emotion) _emotionOptions(),
          if (_kind == WriterKind.choice) _choiceOptions(),

          // Main text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _textCtl,
              maxLines: 5, minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write text here (JLPT inline: 【漢字|かな|meaning】)',
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: (){
                    _textCtl.clear();
                    _speakerCtl.clear();
                    _opt1.clear(); _opt2.clear(); _opt3.clear();
                  },
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: _addBlock,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UI helpers
  Widget _seg(String label, WriterKind k) {
    final on = _kind == k;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_)=>setState(()=>_kind=k),
    );
  }

  Widget _dialogOptions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _speakerCtl,
            decoration: const InputDecoration(labelText: 'Speaker (optional)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Position'),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _posChip('Left',  _Pos.left),
                      _posChip('Right', _Pos.right),
                      _posChip('Mid',   _Pos.mid),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Color'),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _colorDot(Colors.blue.shade100, 'blue'),
                      _colorDot(Colors.pink.shade100, 'pink'),
                      _colorDot(Colors.green.shade100, 'green'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emotionOptions() {
    const emojis = ['🙂','😂','😮','😡','😭','😏','🥰','😱','🤔','😴'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Emotion'),
        child: Wrap(
          spacing: 6,
          children: emojis.map((e)=>ChoiceChip(
            label: Text(e, style: const TextStyle(fontSize: 18)),
            selected: _emotion==e,
            onSelected: (_)=>setState(()=>_emotion=e),
          )).toList(),
        ),
      ),
    );
  }

  Widget _choiceOptions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          TextField(controller: _opt1, decoration: const InputDecoration(labelText: 'Option 1'),),
          const SizedBox(height: 6),
          TextField(controller: _opt2, decoration: const InputDecoration(labelText: 'Option 2'),),
          const SizedBox(height: 6),
          TextField(controller: _opt3, decoration: const InputDecoration(labelText: 'Option 3 (optional)'),),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Reader will see them as buttons (demo).'),
          )
        ],
      ),
    );
  }

  Widget _posChip(String label, _Pos p) {
    return ChoiceChip(
      label: Text(label),
      selected: _pos==p,
      onSelected: (_)=>setState(()=>_pos=p),
    );
  }

  Widget _colorDot(Color c, String code) {
    final selected = _color==code;
    return InkWell(
      onTap: ()=>setState(()=>_color=code),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: selected?3:1),
        ),
      ),
    );
  }

  void _addBlock() {
    final t = _textCtl.text.trim();
    if (t.isEmpty) return _snack('Write something first');

    final eb = EpisodeBlock(
      type: _kind==WriterKind.dialog ? BlockType.dialog : BlockType.narration,
      text: t,
      speaker: _kind==WriterKind.dialog && _speakerCtl.text.trim().isNotEmpty
          ? _speakerCtl.text.trim() : null,
    );
    final meta = _BlockMeta(
      kind: _kind,
      pos: _pos,
      colorCode: _color,
      emotion: _emotion,
      choiceOptions: _kind==WriterKind.choice
          ? [ _opt1.text.trim(), _opt2.text.trim(), _opt3.text.trim() ]
          .where((e)=>e.isNotEmpty).toList()
          : const [],
      speaker: _speakerCtl.text.trim().isNotEmpty ? _speakerCtl.text.trim() : null,
    );

    setState(() {
      _blocks.add(eb);
      _metas.add(meta);
      _textCtl.clear(); _speakerCtl.clear(); _opt1.clear(); _opt2.clear(); _opt3.clear();
      // keep last selected kind/options for speed
    });
  }

  Widget _tile(BuildContext ctx, int i, {Key? key}) {
    final b = _blocks[i];
    final m = _metas[i];
    final isNarr = m.kind==WriterKind.narration || m.kind==WriterKind.monologue || m.kind==WriterKind.action || m.kind==WriterKind.emotion || m.kind==WriterKind.choice;
    final alignEnd = m.pos==_Pos.right;
    final center   = m.pos==_Pos.mid;

    final color = switch (m.colorCode) {
      'pink'  => Colors.pink.shade100,
      'green' => Colors.green.shade100,
      _       => Colors.blue.shade100,
    };

    Widget content;
    switch (m.kind) {
      case WriterKind.narration:
        content = Text(b.text);
        break;
      case WriterKind.dialog:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((b.speaker??'').isNotEmpty)
              Text('${b.speaker}:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            Text(b.text),
          ],
        );
        break;
      case WriterKind.monologue:
        content = Text('『${b.text}』', style: const TextStyle(fontStyle: FontStyle.italic));
        break;
      case WriterKind.action:
        content = Text('[${b.text}]', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54));
        break;
      case WriterKind.emotion:
        content = Text('${m.emotion}  ${b.text}');
        break;
      case WriterKind.choice:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('? ${b.text}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: m.choiceOptions.map((o)=>OutlinedButton(onPressed: (){}, child: Text(o))).toList(),
            ),
          ],
        );
        break;
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(ctx).width * (isNarr ? 0.95 : 0.85)),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (m.kind==WriterKind.dialog) ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: content,
    );

    return Container(
      key: key,
      child: GestureDetector(
        onLongPress: ()=>_editSheet(ctx, i),
        child: Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : (alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start),
          children: [bubble],
        ),
      ),
    );
  }

  void _editSheet(BuildContext ctx, int i) {
    final b = _blocks[i];
    showModalBottomSheet(
      context: ctx,
      builder: (_)=>SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Text'),
              onTap: (){
                Navigator.pop(ctx);
                final c = TextEditingController(text: b.text);
                showDialog(context: ctx, builder: (_)=>AlertDialog(
                  title: const Text('Edit Block'),
                  content: TextField(controller: c, maxLines: 6),
                  actions: [
                    TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(onPressed: (){
                      setState(()=>_blocks[i] = EpisodeBlock(type: b.type, text: c.text, speaker: b.speaker));
                      Navigator.pop(ctx);
                    }, child: const Text('Save')),
                  ],
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: (){
                Navigator.pop(ctx);
                setState((){ _blocks.removeAt(i); _metas.removeAt(i); });
              },
            ),
          ],
        ),
      ),
    );
  }
}
