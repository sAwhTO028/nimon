import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/create_story_basics_form.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Creator route: same unified Story basics form as dock **Create** step 1.
class StoryCreatorBasicsScreen extends ConsumerStatefulWidget {
  const StoryCreatorBasicsScreen({super.key});

  @override
  ConsumerState<StoryCreatorBasicsScreen> createState() =>
      _StoryCreatorBasicsScreenState();
}

class _StoryCreatorBasicsScreenState
    extends ConsumerState<StoryCreatorBasicsScreen> {
  final _formKey = GlobalKey<CreateStoryBasicsFormState>();
  bool _formDirty = false;
  bool _nextBusy = false;

  void _handleAutosaveDraftFields(StoryBasicsDraftFields f) {
    // New untouched sessions must not create/persist anything until first meaningful edit.
    _formDirty = f.isDirty;
    if (!f.isDirty) return;
    ref.read(storyCreatorDraftProvider.notifier).applyBasicsDebounced(
          title: f.title,
          category: (f.category ?? '').trim(),
          level: (f.level ?? '').trim(),
          description: f.description,
          promptSourceNote: '', // not editable on Story basics UI
          coverImageUrl: null, // cover is not persisted as local path in V1
          targetDurationBandKey: switch ((f.durationLabel ?? '').trim()) {
            '3–5 mins' => '3_5',
            '5–7 mins' => '5_7',
            '7–9 mins' => '7_9',
            _ => null,
          },
        );
  }

  Future<void> _attemptExit() async {
    if (!mounted) return;

    // Untouched session: exit immediately (no saves, no prompts).
    if (!_formDirty) {
      if (mounted) context.pop();
      return;
    }

    final draftId = ref.read(storyCreatorDraftDataProvider).id;

    // Dirty session: flush a local save before leaving, so the draft appears in Processing.
    try {
      await ref.read(storyCreatorDraftProvider.notifier).persistLocalNow(
            reason: 'exit_story_basics',
          );
      if (!mounted) return;
      context.pop();
      return;
    } catch (_) {
      // Fall through to confirmation dialog (rare; persistence should normally not throw).
    }

    if (!mounted) return;

    final hasPersisted =
        await ref.read(storyDraftRepositoryProvider).hasDraft(draftId);
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save draft before leaving?'),
        content: Text(
          hasPersisted
              ? 'We couldn’t save your latest changes. What would you like to do?'
              : 'We couldn’t save yet. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard changes'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save_exit'),
            child: const Text('Save and exit'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == null || action == 'cancel') return;

    if (action == 'save_exit') {
      await ref.read(storyCreatorDraftProvider.notifier).persistLocalNow(
            reason: 'exit_story_basics_retry',
          );
      if (!mounted) return;
      context.pop();
      return;
    }

    if (action == 'discard') {
      // If the draft never persisted, ensure nothing remains in local storage.
      if (!hasPersisted) {
        await ref.read(storyDraftRepositoryProvider).deleteDraft(draftId);
      }
      ref.read(storyCreatorDraftProvider.notifier).reset();
      if (!mounted) return;
      context.pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncCreatorDrawerSessionFromContext(context, ref);
  }

  Future<void> _continue() async {
    if (_nextBusy) return;
    final payload = _formKey.currentState?.buildPayloadIfValid();
    if (payload == null) return;
    setState(() => _nextBusy = true);
    ref.read(storyCreatorDraftProvider.notifier).applyBasics(
          title: payload.title,
          category: payload.category,
          level: payload.level,
          description: payload.description,
          promptSourceNote: payload.promptSourceNote,
          targetDurationBandKey: payload.targetDurationBandKey,
          coverImageUrl: payload.coverImageUrl,
        );
    if (!mounted) return;
    final d = ref.read(storyCreatorDraftDataProvider);
    context.push('/create/story/sentences?draftId=${d.id}');
    if (mounted) setState(() => _nextBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeDraftId = GoRouterState.of(context).uri.queryParameters['draftId'];
    final cleanedRouteId =
        (routeDraftId == null || routeDraftId.trim().isEmpty) ? null : routeDraftId.trim();
    if (cleanedRouteId != null) {
      final current = ref.watch(storyCreatorDraftDataProvider);
      if (current.id != cleanedRouteId) {
        unawaited(ref.read(storyCreatorDraftProvider.notifier).loadDraftById(cleanedRouteId));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Story basics'),
            leading: NimonBackButton(onPressed: () => context.pop()),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final canContinue = _formKey.currentState?.isStep1Complete ?? false;
    final nextEnabled = canContinue && !_nextBusy;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_attemptExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Story basics'),
          leading: NimonBackButton(
            onPressed: () => unawaited(_attemptExit()),
          ),
          actions: [
            IconButton(
              tooltip: 'Progress',
              onPressed: () => _formKey.currentState?.showProgressBottomSheet(),
              icon: const Icon(Icons.error_outline_rounded),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 2),
            TextButton(
              onPressed: nextEnabled ? () => unawaited(_continue()) : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
              child: _nextBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Next'),
            ),
            const SizedBox(width: 10),
          ],
        ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CreateStoryBasicsForm(
              key: _formKey,
              initialDraft: draft,
              progressSheetActionLabel: 'Continue',
              onFieldsChanged: () => setState(() {}),
              onDraftFieldsChanged: _handleAutosaveDraftFields,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
