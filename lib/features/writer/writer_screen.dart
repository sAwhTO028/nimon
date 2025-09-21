import 'package:flutter/material.dart';
import 'package:nimon/core/responsive.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/story.dart';

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
  final _repo = StoryRepoMock();

  List<EpisodeBlock> blocks = [];
  final _controller = TextEditingController();
  BlockType _type = BlockType.narration;
  final _speakerCtl = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _speakerCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = R.hPad(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Episode'),
        actions: [
          IconButton(
              tooltip: 'Save (draft)',
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveDraft),
          IconButton(
            tooltip: 'Upload (UI-only)',
            icon: const Icon(Icons.cloud_upload_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('UI-only: AI check → upload')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12).add(pad),
              child: ReorderableListView.builder(
                itemCount: blocks.length,
                onReorder: (o, n) {
                  setState(() {
                    if (n > o) n -= 1;
                    final it = blocks.removeAt(o);
                    blocks.insert(n, it);
                  });
                },
                itemBuilder: (c, i) => _Bubble(
                  key: ValueKey(blocks[i].id),
                  block: blocks[i],
                  onEdit: () => _edit(i),
                  onDelete: () => setState(() => blocks.removeAt(i)),
                ),
              ),
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
    final spk =
    _type == BlockType.narration ? null : (_speakerCtl.text.trim().isEmpty ? 'YOU' : _speakerCtl.text.trim());

    setState(() {
      blocks.add(EpisodeBlock(
        id: UniqueKey().toString(),
        type: _type,
        text: txt,
        speaker: spk,
      ));
      _controller.clear();
    });
  }

  void _edit(int i) {
    final b = blocks[i];
    _controller.text = b.text;
    _speakerCtl.text = b.speaker ?? '';
    setState(() => _type = b.type);
    blocks.removeAt(i);
  }

  Future<void> _saveDraft() async {
    final text = blocks.map((b) => b.toLine()).join('\n\n');
    final episode = Episode(
      id: '',
      storyId: widget.storyId,
      index: 0, // mock repo ထဲက auto index ပေးမယ်ဆိုရင် 0 ထား
      jlptLevel: 'N5',
      text: text,
      preview: text.length > 80 ? '${text.substring(0, 80)}…' : text,
    );

    try {
      // mock repo signature မတူနိုင်လို့ 2 နည်းစလုံးစမ်း
      try {
        // ignore: invalid_use_of_protected_member
        await (_repo as dynamic).addEpisode(episode);
      } catch (_) {
        // ignore: invalid_use_of_protected_member
        await (_repo as dynamic).addEpisode(episode);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft saved (mock)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    }
  }
}

/// local draft block
class EpisodeBlock {
  final String id;
  final BlockType type;
  final String text;
  final String? speaker;
  EpisodeBlock({
    required this.id,
    required this.type,
    required this.text,
    this.speaker,
  });

  String toLine() {
    switch (type) {
      case BlockType.narration:
        return text;
      case BlockType.dialogMe:
        return '${speaker ?? "ME"}: $text';
      case BlockType.dialogYou:
        return '${speaker ?? "YOU"}: $text';
      case BlockType.mind:
        return '( $text )';
    }
  }
}

class _Bubble extends StatelessWidget {
  final EpisodeBlock block;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _Bubble({super.key, required this.block, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final radius = R.radius(context);

    if (block.type == BlockType.narration) {
      // FULL-WIDTH narration
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: radius,
                child: InkWell(
                  borderRadius: radius,
                  onLongPress: () => _menu(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(block.text, style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isMe = block.type == BlockType.dialogMe;
    final color = isMe ? Colors.lightBlue.shade100 : Colors.pink.shade100;
    final align = isMe ? MainAxisAlignment.start : MainAxisAlignment.end;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (block.speaker != null)
            Padding(
              padding: EdgeInsets.only(left: isMe ? 6 : 0, right: isMe ? 0 : 6, bottom: 4),
              child: Text(block.speaker!, style: Theme.of(context).textTheme.labelSmall),
            ),
          Row(
            mainAxisAlignment: align,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width * 0.75).clamp(260, 640),
                ),
                child: Material(
                  color: color,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
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
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
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
    final pad = R.hPad(context);
    final isDialog = type != BlockType.narration;
    return SafeArea(
      top: false,
      child: Padding(
        padding: pad.add(const EdgeInsets.fromLTRB(0, 8, 0, 12)),
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
