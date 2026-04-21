import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';

/// Shared overlays (bottom sheets) for the Grammar module.
abstract final class StoryCreatorGrammarOverlays {
  StoryCreatorGrammarOverlays._();

  static void showHowTo(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.78),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to create Grammar patterns',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HelpSection(
                    title: 'Grammar pattern',
                    body:
                        'Add one grammar structure readers should learn from this story.',
                  ),
                  const SizedBox(height: 12),
                  _HelpSection(
                    title: 'Main input',
                    body:
                        'Source language is the main field. This is the primary grammar pattern learners will study.',
                  ),
                  const SizedBox(height: 12),
                  _HelpSection(
                    title: 'Optional support',
                    body:
                        'Common English can be added optionally. Keep optional content collapsed / secondary when possible.',
                  ),
                  const SizedBox(height: 12),
                  _HelpSection(
                    title: 'Examples',
                    body:
                        'Add example sentences to show usage. V1 supports up to 3 examples.',
                  ),
                  const SizedBox(height: 12),
                  _HelpSection(
                    title: 'Completion',
                    body:
                        'Grammar becomes complete only when at least one valid pattern exists.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// V1 “test-play” for Grammar: lightweight review of what’s been created so far.
  static void showTestPlay(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.read(storyCreatorDraftDataProvider);
    final items = draft.grammar.entries;

    String? meaningLine(GrammarEntry e) {
      final m = e.meanings;
      if (m == null) return null;
      final source = m.my?.trim();
      final en = m.en?.trim();
      if (source != null && source.isNotEmpty) return source;
      if (en != null && en.isNotEmpty) return en;
      return null;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'Test-play grammar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${items.length} ${items.length == 1 ? 'pattern' : 'patterns'} created so far.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(
                  'No grammar patterns yet. Tap “Add pattern” to create one.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                )
              else
                for (final e in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.headline,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (meaningLine(e) != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              meaningLine(e)!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                          ],
                          if ((e.form ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              e.form!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _HowItWorksBullet extends StatelessWidget {
  const _HowItWorksBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 8, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface.withValues(alpha: 0.86),
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

