// C:\nimon\nimon\lib\features\writer\writer_screen.dart
import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/models/episode.dart';

class WriterScreen extends StatefulWidget {
  final String storyId;
  final int nextOrder;
  const WriterScreen({super.key, required this.storyId, required this.nextOrder});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  String _type = 'narration';
  String _speaker = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = StoryRepoMock();
    final ep = Episode(
      id: 'e_${DateTime.now().millisecondsSinceEpoch}',
      storyId: widget.storyId,
      order: widget.nextOrder,
      type: _type,
      speaker: _type == 'dialog' ? _speaker : null,
      text: _controller.text.trim(),
    );
    await repo.addEpisode(storyId: widget.storyId, episode: ep); // <-- named args
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Published!'),
      content: const Text('XP +20, Coins +5 (demo)'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))],
    )).then((_){ Navigator.pop(context); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write Episode')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            DropdownButtonFormField(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'narration', child: Text('Narration')),
                DropdownMenuItem(value: 'dialog', child: Text('Dialog')),
              ],
              onChanged: (v){ setState(()=>_type = v!); },
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            if (_type=='dialog')
              TextFormField(
                decoration: const InputDecoration(labelText: 'Speaker'),
                onChanged: (v)=>_speaker=v,
                validator: (v)=> (v==null||v.isEmpty)?'Speaker required':null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'N5 words only (demo)',
                border: OutlineInputBorder(),
              ),
              validator: (v)=> (v==null||v.trim().isEmpty)?'Write something':null,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.upload), label: const Text('Publish')),
          ]),
        ),
      ),
    );
  }
}
