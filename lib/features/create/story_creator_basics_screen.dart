import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/create_story_basics_form.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
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
  final _formKey = GlobalKey<CreateStoryBasicsFormState>(
    debugLabel: 'StoryCreatorBasicsScreen_form',
  );
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
    await handleCreatorBackPressed(
      context,
      ref,
      storyBasicsHasMeaningfulEdits: _formDirty,
    );
  }

  @override
  void didChangeDependencies() {
    // Build should render only. Route/session sync is owned by CreatorRouteSyncListener.
    super.didChangeDependencies();
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
    if (!mounted) return const SizedBox.shrink();
    try {
      final r = GoRouter.maybeOf(context);
      if (r == null || !r.state.uri.path.startsWith('/create/story')) {
        return const SizedBox.shrink();
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    String? routeDraftId;
    try {
      routeDraftId = GoRouterState.of(context).uri.queryParameters['draftId'];
    } catch (_) {
      // During route transitions this element can be deactivating; avoid inherited
      // lookups that can throw ("deactivated widget's ancestor is unsafe").
      routeDraftId = null;
    }
    final cleanedRouteId =
        (routeDraftId == null || routeDraftId.trim().isEmpty) ? null : routeDraftId.trim();
    if (cleanedRouteId != null) {
      final current = ref.watch(storyCreatorDraftDataProvider);
      if (current.id != cleanedRouteId) {
        // Draft load is owned by [syncCreatorDrawerSessionForRouter] + [_reconcileDraftIdWithRouter]
        // from [CreatorRouteSyncListener] — not from build().
        return Scaffold(
          appBar: AppBar(
            title: const Text('Story basics'),
            leading: NimonBackButton(
                onPressed: () => unawaited(_attemptExit()),
              ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final canContinue = _formKey.currentState?.isStep1Complete ?? false;
    final nextEnabled = canContinue && !_nextBusy;

    return CreatorRouteSyncListener(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (kDebugMode) {
            String u = '(no_uri)';
            try {
              u = GoRouter.maybeOf(context)?.state.uri.toString() ?? u;
            } catch (_) {}
            debugPrint(
              '[NIMON_BACK_TRACE] StoryCreatorBasicsScreen PopScope '
              'didPop=$didPop result=$result uri=$u -> _attemptExit',
            );
          }
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
      ),
    );
  }
}
