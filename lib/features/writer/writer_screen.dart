import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';

enum WriterKind { narration, dialog, monologue, emotion }
enum _Pos { left, mid, right }

/// UI-only metadata for each block (model ကို မထိ)
class _BlockMeta {
  _BlockMeta({
    required this.kind,
    this.pos = _Pos.left,
    this.colorCode = 'blue', // auto-mapped from pos
    this.emoji = '🙂',
    this.speaker,
  });

  WriterKind kind;
  _Pos pos;
  String colorCode; // blue | green | pink
  String emoji;     // for emotion
  String? speaker;  // for dialog
}

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key, required this.repo, required this.storyId});
  final StoryRepo repo;
  final String storyId;

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  // ===== compose state (global) =====
  WriterKind _kind = WriterKind.narration;

  // alignment/color is single control (mapping)
  _Pos _pos = _Pos.left;       // left=blue, mid=green, right=pink
  String get _colorFromPos => switch (_pos) {
    _Pos.left => 'blue',
    _Pos.mid  => 'green',
    _Pos.right=> 'pink',
  };

  // emotion palette (shown only when kind==emotion)
  String _emoji = '🙂';

  // dialog speaker (optional)
  final _speakerCtl = TextEditingController();

  // main text
  final _textCtl = TextEditingController();

  // data store (blocks + metas — same length)
  final List<EpisodeBlock> _blocks = [];
  final List<_BlockMeta> _metas = [];

  @override
  void dispose() {
    _speakerCtl.dispose();
    _textCtl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Writer'),
        actions: [
          IconButton(
            tooltip: 'AI check (demo)',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: () => _snack('AI check queued (demo)'),
          ),
          IconButton(
            tooltip: 'Save (demo)',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _snack('Saved (demo)'),
          ),
          IconButton(
            tooltip: 'Upload (demo)',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => _snack('Upload queued (demo)'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== blocks list (reorderable) =====
          Expanded(
            child: _blocks.isEmpty
                ? const Center(child: Text('No content yet. Write something below.'))
                : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _blocks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final b = _blocks.removeAt(oldIndex);
                  final m = _metas.removeAt(oldIndex);
                  _blocks.insert(newIndex, b);
                  _metas.insert(newIndex, m);
                });
              },
              proxyDecorator: (child, _, __) => Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (ctx, i) => _blockTile(ctx, i, key: ValueKey('block_$i')),
            ),
          ),

          const Divider(height: 1),

          // ===== KIND selector =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _kindChip('Narration', WriterKind.narration),
                _kindChip('Dialog',    WriterKind.dialog),
                _kindChip('Monologue', WriterKind.monologue),
                _kindChip('Emotion',   WriterKind.emotion),
              ],
            ),
          ),

          // ===== CONTEXT OPTIONS BAR (shows directly UNDER the chips) =====
          _contextOptionsBar(),

          // ===== main text input =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _textCtl,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write here…',
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ===== clear / add =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    _textCtl.clear();
                    _speakerCtl.clear();
                  },
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _onAddPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== UI parts =====
  Widget _kindChip(String label, WriterKind k) {
    final on = _kind == k;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _kind = k),
    );
  }

  Widget _contextOptionsBar() {
    // Common: alignment (pos) tri-toggle (maps color automatically)
    Widget alignRow = InputDecorator(
      decoration: const InputDecoration(border: InputBorder.none, labelText: 'Align (maps color)'),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _posChip('Left  (Blue)', _Pos.left),
          _posChip('Mid (Green)',  _Pos.mid),
          _posChip('Right (Pink)', _Pos.right),
          // color hint
          _colorTag(_colorFromPos),
        ],
      ),
    );

    // Dialog: show Speaker + Align
    if (_kind == WriterKind.dialog) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: Column(
          children: [
            TextField(
              controller: _speakerCtl,
              decoration: const InputDecoration(
                labelText: 'Speaker (optional)',
                hintText: 'e.g. AYANA',
              ),
            ),
            const SizedBox(height: 4),
            alignRow,
          ],
        ),
      );
    }

    // Emotion: show emoji palette + Align
    if (_kind == WriterKind.emotion) {
      const emojis = ['🙂','😂','😮','😡','😭','🥰','😱','🤔','😴','😏'];
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(border: InputBorder.none, labelText: 'Emotion'),
              child: Wrap(
                spacing: 6,
                children: emojis.map((e) => ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 18)),
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                )).toList(),
              ),
            ),
            const SizedBox(height: 4),
            alignRow,
          ],
        ),
      );
    }

    // Monologue: align only
    if (_kind == WriterKind.monologue) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: alignRow,
      );
    }

    // Narration: align only (သင်ချင်သလို သိမ်း)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: alignRow,
    );
  }

  Widget _posChip(String label, _Pos p) {
    return ChoiceChip(
      label: Text(label),
      selected: _pos == p,
      onSelected: (_) => setState(() => _pos = p),
    );
  }

  Widget _colorTag(String code) {
    final c = switch (code) {
      'pink'  => Colors.pink.shade100,
      'green' => Colors.green.shade100,
      _       => Colors.blue.shade100,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('Color: $code'),
    );
  }

  void _onAddPressed() {
    final t = _textCtl.text.trim();
    if (t.isEmpty) return _snack('Type something first');

    // map WriterKind → model BlockType (dialog only uses dialog, rest = narration)
    final bt = (_kind == WriterKind.dialog) ? BlockType.dialog : BlockType.narration;

    // inline formatting for monologue/emotion (simple)
    final text = switch (_kind) {
      WriterKind.monologue => '『$t』',
      WriterKind.emotion   => '$_emoji $t',
      _                    => t,
    };

    final ep = EpisodeBlock(
      type: bt,
      text: text,
      speaker: (_kind == WriterKind.dialog && _speakerCtl.text.trim().isNotEmpty)
          ? _speakerCtl.text.trim()
          : null,
    );

    setState(() {
      _blocks.add(ep);
      _metas.add(_BlockMeta(
        kind: _kind,
        pos: _pos,
        colorCode: _colorFromPos,
        emoji: _emoji,
        speaker: (_kind == WriterKind.dialog && _speakerCtl.text.trim().isNotEmpty)
            ? _speakerCtl.text.trim()
            : null,
      ));
      _textCtl.clear();
      _speakerCtl.clear();
      // keep kind / pos / emoji for fast continuous writing
    });
  }

  Widget _blockTile(BuildContext ctx, int i, {Key? key}) {
    final b = _blocks[i];
    final m = _metas[i];
    final align = switch (m.pos) {
      _Pos.left  => MainAxisAlignment.start,
      _Pos.mid   => MainAxisAlignment.center,
      _Pos.right => MainAxisAlignment.end,
    };
    final isDialog = m.kind == WriterKind.dialog;
    final color = switch (m.colorCode) {
      'pink'  => Colors.pink.shade100,
      'green' => Colors.green.shade100,
      _       => Colors.blue.shade100,
    };

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(ctx).width * (isDialog ? 0.85 : 0.95)),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDialog ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDialog && (b.speaker ?? '').isNotEmpty)
            Text('${b.speaker}:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(b.text),
        ],
      ),
    );

    return Container(
      key: key, // REQUIRED for ReorderableListView to track item
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: align,
        children: [
          // drag handle + content (handle makes reorder more obvious)
          ReorderableDragStartListener(
            index: i,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.drag_indicator),
            ),
          ),
          // content with long-press edit
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showEditSheet(ctx, i),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, int index) {
    final b = _blocks[index];
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                final c = TextEditingController(text: b.text);
                showDialog(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('Edit Block'),
                    content: TextField(controller: c, maxLines: 6),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _blocks[index] = EpisodeBlock(
                              type: b.type,
                              text: c.text,        // <-- update text (bug fix)
                              speaker: b.speaker,  // keep same
                            );
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _blocks.removeAt(index);
                  _metas.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
