import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key, required this.repo, required this.storyId});
  final StoryRepo repo;
  final String storyId;

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

/// UI-only meta for each block (alignment/color)
class _BlockMeta {
  _BlockMeta(this.pos, this.colorCode);
  String pos;        // 'left' | 'right' | 'mid'
  String colorCode;  // 'blue' | 'pink' | 'green'
}

class _WriterScreenState extends State<WriterScreen> {
  final _textCtl = TextEditingController();
  final _speakerCtl = TextEditingController();

  // compose state
  BlockType _type = BlockType.narration;
  String _pos = 'left';
  String _bubbleColor = 'blue';

  final List<EpisodeBlock> _blocks = [];
  final List<_BlockMeta> _metas = []; // same length with _blocks

  @override
  void dispose() {
    _textCtl.dispose();
    _speakerCtl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  PreferredSizeWidget _writerAppBar() {
    return AppBar(
      title: const Text('Write Episode'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'Save (demo)',
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () => _snack('Saved (demo)'),
        ),
        IconButton(
          tooltip: 'AI check (demo)',
          icon: const Icon(Icons.psychology_alt_outlined),
          onPressed: () => _snack('Queued for AI check (demo)'),
        ),
        IconButton(
          tooltip: 'Reader preview (demo)',
          icon: const Icon(Icons.remove_red_eye_outlined),
          onPressed: () => _snack('Preview not implemented (demo)'),
        ),
        IconButton(
          tooltip: 'Upload (demo)',
          icon: const Icon(Icons.cloud_upload_outlined),
          onPressed: () => _snack('Upload queued (demo)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _writerAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // ===== Blocks list =====
            Expanded(
              child: _blocks.isEmpty
                  ? const Center(
                child: Text('No content yet. Write something below.'),
              )
                  : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _blocks.length,
                itemBuilder: (ctx, i) {
                  final b = _blocks[i];
                  return _blockTile(ctx, b, i, key: ValueKey('block_$i'));
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final movedBlock = _blocks.removeAt(oldIndex);
                    final movedMeta = _metas.removeAt(oldIndex);
                    _blocks.insert(newIndex, movedBlock);
                    _metas.insert(newIndex, movedMeta);
                  });
                },
              ),
            ),

            const Divider(height: 1),

            // ===== Type toggle =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ToggleButtons(
                  isSelected: [
                    _type == BlockType.narration,
                    _type == BlockType.dialog,
                  ],
                  onPressed: (i) =>
                      setState(() => _type = i == 0 ? BlockType.narration : BlockType.dialog),
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 120),
                  borderRadius: BorderRadius.circular(14),
                  children: const [Text('Narration'), Text('Dialog')],
                ),
              ),
            ),

            // ===== Dialog options =====
            if (_type == BlockType.dialog) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _speakerCtl,
                  decoration: const InputDecoration(
                    labelText: 'Speaker',
                    hintText: 'e.g. AYANA / YAMADA',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Left'),
                      selected: _pos == 'left',
                      onSelected: (_) => setState(() => _pos = 'left'),
                    ),
                    ChoiceChip(
                      label: const Text('Right'),
                      selected: _pos == 'right',
                      onSelected: (_) => setState(() => _pos = 'right'),
                    ),
                    ChoiceChip(
                      label: const Text('Mid'),
                      selected: _pos == 'mid',
                      onSelected: (_) => setState(() => _pos = 'mid'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Color:'),
                    _colorDot(Colors.blue.shade100, 'blue'),
                    _colorDot(Colors.pink.shade100, 'pink'),
                    _colorDot(Colors.green.shade100, 'green'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ===== Composer =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textCtl,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(hintText: 'Say anything...'),
              ),
            ),
            const SizedBox(height: 8),

            // ===== Clear (left) — Add (right) =====
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
      ),
    );
  }

  // ===== Helpers =====
  Widget _colorDot(Color c, String code) {
    final selected = _bubbleColor == code;
    return InkWell(
      onTap: () => setState(() => _bubbleColor = code),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: selected ? 3 : 1),
        ),
      ),
    );
  }

  void _onAddPressed() {
    final text = _textCtl.text.trim();
    if (text.isEmpty) {
      _snack('Type something first');
      return;
    }

    final block = EpisodeBlock(
      type: _type,
      text: text,
      speaker: _type == BlockType.dialog && _speakerCtl.text.trim().isNotEmpty
          ? _speakerCtl.text.trim()
          : null,
    );

    setState(() {
      _blocks.add(block);
      _metas.add(_BlockMeta(_pos, _bubbleColor)); // keep meta in parallel
      _textCtl.clear();
      _speakerCtl.clear();
    });
  }

  Widget _blockTile(BuildContext ctx, EpisodeBlock b, int i, {Key? key}) {
    final isNarr = b.type == BlockType.narration;

    // meta for alignment / color
    _BlockMeta meta = (i < _metas.length) ? _metas[i] : _BlockMeta('left', 'blue');
    final alignEnd = meta.pos == 'right';
    final center = meta.pos == 'mid';

    final color = switch (meta.colorCode) {
      'pink' => Colors.pink.shade100,
      'green' => Colors.green.shade100,
      _ => Colors.blue.shade100,
    };

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(ctx).width * (isNarr ? 0.95 : 0.85),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNarr ? Colors.white : color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isNarr && (b.speaker ?? '').isNotEmpty)
            Text('${b.speaker}:',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(b.text),
        ],
      ),
    );

    return Container(
      key: key, // required for ReorderableListView
      child: GestureDetector(
        onLongPress: () => _showEditSheet(ctx, b, i),
        child: Row(
          mainAxisAlignment: center
              ? MainAxisAlignment.center
              : (alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start),
          children: [bubble],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, EpisodeBlock b, int index) {
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
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _blocks[index] = EpisodeBlock(
                              type: b.type,
                              text: c.text,
                              speaker: b.speaker,
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
                  if (index < _metas.length) {
                    _metas.removeAt(index);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
