// lib/features/mono/start_mono_sheet.dart
import 'package:flutter/material.dart';

class StartMonoSheet extends StatefulWidget {
  const StartMonoSheet({super.key});
  @override
  State<StartMonoSheet> createState() => _StartMonoSheetState();
}

class _StartMonoSheetState extends State<StartMonoSheet> {
  int step = 0;
  String level = 'N4';
  String type = 'Love & Horror';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add MONO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                FilledButton(onPressed: () {}, child: const Text('START')),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (step + 1) / 3, minHeight: 6, borderRadius: BorderRadius.circular(12)),
            const SizedBox(height: 16),
            Card(child: ListTile(title: const Text('Select your level'), subtitle: Text(level), onTap: () => setState(() => step = 0))),
            Card(child: ListTile(title: const Text('Select Mono Type'), subtitle: Text(type), onTap: () => setState(() => step = 1))),
            Card(
              child: const ListTile(
                title: Text('If You Want AI Generate'),
                subtitle: Text('Free user 3 times left\nPrompt Description - Details…'),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
