import 'package:flutter/material.dart';

class WriterScreen extends StatefulWidget {
  final String storyId;
  const WriterScreen({super.key, required this.storyId});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

enum BlockType { narration, dialogMe, dialogYou, mind }

class _WriterScreenState extends State<WriterScreen> {
  final _controller = TextEditingController();
  final _speaker = TextEditingController();
  BlockType _type = BlockType.narration;
  final List<_Block> _blocks = [];

  @override
  void dispose() { _controller.dispose(); _speaker.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDialog = _type != BlockType.narration;
    return Scaffold(
      appBar: AppBar(title: const Text('Write Episode')),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (o, n) { setState(() { if (n>o) n-=1; final it=_blocks.removeAt(o); _blocks.insert(n, it); }); },
              children: [
                for (final b in _blocks)
                  _Bubble(key: ValueKey(b.id), block: b,
                      onEdit: ()=>_edit(b),
                      onDelete: ()=>setState(() => _blocks.removeWhere((x)=>x.id==b.id))),
              ],
            ),
          ),
          SafeArea(
            top:false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12,8,12,12),
              child: Column(children: [
                Row(children: [
                  SegmentedButton<BlockType>(
                    segments: const [
                      ButtonSegment(value: BlockType.narration, label: Text('Narr')),
                      ButtonSegment(value: BlockType.dialogMe, label: Text('Say Me')),
                      ButtonSegment(value: BlockType.dialogYou, label: Text('Say You')),
                      ButtonSegment(value: BlockType.mind, label: Text('Mind')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s)=>setState(()=>_type=s.first),
                  ),
                  const SizedBox(width:8),
                  if (isDialog) SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _speaker,
                      decoration: const InputDecoration(labelText: 'Speaker', isDense: true, border: OutlineInputBorder()),
                    ),
                  )
                ]),
                const SizedBox(height:8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _controller, minLines:1, maxLines:4,
                    decoration: const InputDecoration(hintText: 'Say anything…', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width:8),
                  IconButton.filled(
                    onPressed: _add,
                    icon: const Icon(Icons.send_rounded),
                  )
                ])
              ]),
            ),
          )
        ],
      ),
    );
  }

  void _add(){
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    final spk = _type==BlockType.narration ? null : (_speaker.text.trim().isEmpty ? 'YOU' : _speaker.text.trim());
    setState(() {
      _blocks.add(_Block(id: UniqueKey().toString(), type: _type, text: txt, speaker: spk));
      _controller.clear();
    });
  }

  void _edit(_Block b){
    _controller.text = b.text;
    _speaker.text = b.speaker ?? '';
    setState(() { _type = b.type; _blocks.removeWhere((x)=>x.id==b.id); });
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
  final VoidCallback onEdit, onDelete;
  const _Bubble({super.key, required this.block, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (block.type == BlockType.narration) {
      return Container(
        key: key, margin: const EdgeInsets.symmetric(vertical:8),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: ()=>_menu(context),
            child: Padding(padding: const EdgeInsets.all(16), child: Text(block.text)),
          ),
        ),
      );
    }
    final isMe = block.type == BlockType.dialogMe;
    final color = isMe ? Colors.lightBlue.shade100 : Colors.pink.shade100;
    return Container(
      key: key, margin: const EdgeInsets.symmetric(vertical:6),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (block.speaker!=null)
            Padding(padding: EdgeInsets.only(left:isMe?6:0, right:isMe?0:6, bottom:4),
                child: Text(block.speaker!, style: Theme.of(context).textTheme.labelSmall)),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width*0.75).clamp(260,640)),
                child: Material(
                  color: color, borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onLongPress: ()=>_menu(context),
                    child: Padding(padding: const EdgeInsets.all(14), child: Text(block.text)),
                  ),
                ),
              )
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
        PopupMenuItem(value:'edit', child: Text('Edit')),
        PopupMenuItem(value:'delete', child: Text('Delete')),
      ],
    );
    if (res=='edit') onEdit();
    if (res=='delete') onDelete();
  }
}
