import 'package:flutter/material.dart';
import '../widgets/red_square.dart';

class MonoScreen extends StatelessWidget {
  const MonoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mono')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Mono'),
        onPressed: () {
          showModalBottomSheet(
            context: context, isScrollControlled: true,
            builder: (_) => const _StartMonoSheet(),
          );
        },
      ),
      body: const Center(child: Text('Your mono list (UI-only)')),
    );
  }
}

class _StartMonoSheet extends StatefulWidget {
  const _StartMonoSheet();
  @override
  State<_StartMonoSheet> createState() => _StartMonoSheetState();
}

class _StartMonoSheetState extends State<_StartMonoSheet> {
  int step = 0;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16,16,16,24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Start Mono', style: TextStyle(fontSize: 18,fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.close), onPressed: ()=>Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          Stepper(
            currentStep: step,
            onStepContinue: () => setState(()=> step = (step+1).clamp(0,2)),
            onStepCancel: () => setState(()=> step = (step-1).clamp(0,2)),
            steps: const [
              Step(title: Text('Select Type'), content: Text('current/new or QR code (UI-only)')),
              Step(title: Text('Confirm Level'), content: Text('N5/N4/N3 (UI-only)')),
              Step(title: Text('Ready'), content: Text('AI check → upload ready (UI-only)')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tap the red square to go next screen (arrow slide):'),
          const SizedBox(height: 8),
          const RedSquare(),
        ]),
      ),
    );
  }
}
