import 'package:flutter/material.dart';

class WriterArgs {
  final String storyId;
  WriterArgs(this.storyId);
}

class WriterScreen extends StatefulWidget {
  static const routeName = '/writer';
  final String storyId;
  const WriterScreen({super.key, required this.storyId});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

enum BlockType { narration, dialogMe, dialogYou, mind }

class _WriterScreenState extends State<WriterScreen> {
  final _controller = TextEditingController();
  final _speakerCtl = TextEditingController();
  BlockType _type = BlockType.narration;
  final List<_Block> _blocks = [];

  @override
  void dispose() {
    _controller.dispose();
    _speakerCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Episode'),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Saved draft (UI-only, not persisted)')),
            ),
            icon: const Icon(Icons.save_rounded),
          ),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Upload → AI check (UI-only)')),
            ),
            icon: const Icon(Icons.cloud_upload_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n -= 1;
                  final it = _blocks.removeAt(o);
                  _blocks.insert(n, it);
                });
              },
              children: [
                for (final b in _blocks)
                  _Bubble(
                    key: ValueKey(b.id),
                    block: b,
                    onEdit: () => _edit(b),
                    onDelete: () =>
                        setState(() => _blocks.removeWhere((x) => x.id == b.id)),
                  ),
              ],
            ),
          ),
          _Composer(
            type: _type,
            onTypeChanged: (t) => setState(() => _type = t),
            textController: _controller,
            speakerController: _speakerCtl,
            onSend: _add,
          ),
        ],
      ),
    );
  }

  void _add() {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _blocks.add(_Block(
        id: UniqueKey().toString(),
        type: _type,
        text: txt,
        speaker: _type == BlockType.narration
            ? null
            : (_speakerCtl.text.trim().isEmpty ? 'YOU' : _speakerCtl.text),
      ));
      _controller.clear();
    });
  }

  void _edit(_Block b) {
    _controller.text = b.text;
    _speakerCtl.text = b.speaker ?? '';
    setState(() {
      _type = b.type;
      _blocks.removeWhere((x) => x.id == b.id);
    });
  }
}

class _Block {
  final String id;
  final BlockType type;
  final String text;
  final String? speaker;
  _Block({required this.id, required this.type, required this.text, this.speaker});
}

class _Bubble extends StatelessWidget {
  final _Block block;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _Bubble({super.key, required this.block, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (block.type == BlockType.narration) {
      // full-width bar
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: () => _menu(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(block.text),
            ),
          ),
        ),
      );
    }
    final isMe = block.type == BlockType.dialogMe;
    final color = isMe ? Colors.lightBlue.shade100 : Colors.pink.shade100;
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (block.speaker != null)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 6 : 0,
                right: isMe ? 0 : 6,
                bottom: 4,
              ),
              child: Text(block.speaker!, style: Theme.of(context).textTheme.labelSmall),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.75).clamp(260, 640),
                ),
                child: Material(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onLongPress: () => _menu(context),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(block.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _menu(BuildContext context) async {
    final res = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 16, 0),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (res == 'edit') onEdit();
    if (res == 'delete') onDelete();
  }
}

class _Composer extends StatelessWidget {
  final BlockType type;
  final ValueChanged<BlockType> onTypeChanged;
  final TextEditingController textController;
  final TextEditingController speakerController;
  final VoidCallback onSend;

  const _Composer({
    required this.type,
    required this.onTypeChanged,
    required this.textController,
    required this.speakerController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDialog = type != BlockType.narration;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                SegmentedButton<BlockType>(
                  segments: const [
                    ButtonSegment(value: BlockType.narration, label: Text('Narr')),
                    ButtonSegment(value: BlockType.dialogMe, label: Text('Say Me')),
                    ButtonSegment(value: BlockType.dialogYou, label: Text('Say You')),
                    ButtonSegment(value: BlockType.mind, label: Text('Mind')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => onTypeChanged(s.first),
                ),
                const SizedBox(width: 8),
                if (isDialog)
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: speakerController,
                      decoration: const InputDecoration(
                        labelText: 'Speaker',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Say Anything…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
