import 'package:flutter/material.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 placeholder for Help & Feedback (linked from Settings).
class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Feedback'),
        leading: const NimonBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'We are building Nimon step by step. If something breaks or feels confusing, we want to hear about it.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          Text(
            'V1',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In-app feedback and support tickets are not wired yet. For now, use whatever channel you normally use to reach the team (e.g. project chat or email).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thanks — full feedback flow is coming later.'),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
              ),
            ),
            icon: const Icon(Icons.thumb_up_outlined),
            label: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
