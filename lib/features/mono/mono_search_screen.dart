import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_layout.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 placeholder for Mono feed search (opened from Mono top bar).
class MonoSearchScreen extends StatelessWidget {
  const MonoSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Mono'),
        centerTitle: false,
        leading: const NimonBackButton(),
      ),
      body: NimonReadingColumn.wrap(
        context,
        Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Text(
            'Search across the Mono feed will be available in a future update.',
            style: theme.type.storyCardSummary(theme, context.widthClass).copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.start,
          ),
        ),
      ),
    );
  }
}
