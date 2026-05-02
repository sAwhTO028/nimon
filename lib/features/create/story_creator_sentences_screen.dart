import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_navigation_debug.dart';
import 'package:nimon/features/create/creator_quiz_ui_state.dart';
import 'package:nimon/features/create/creator_reorder_handle.dart';
import 'package:nimon/features/create/creator_drawer_publish.dart';
import 'package:nimon/features/create/creator_learn_mode_sync.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/creator_workspace_module_placeholder.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/creator_read_only_publish_tracking.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/features/create/story_creator_quiz_editor_screen.dart';
import 'package:nimon/features/create/story_creator_vocab_kanji_editor_screen.dart';
import 'package:nimon/features/create/story_creator_grammar_overlays.dart';
import 'package:nimon/features/create/story_creator_furigana_tokens.dart';
import 'package:nimon/ui/reading/nimon_japanese_sentence_line.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Visible title for the pinned workspace header on `/create/story/sentences`
/// (driven by the router `?panel=` on that host; see [syncCreatorDrawerSessionForRouter]).
String _pinnedWorkspaceTitle(CreatorWorkspaceStep step) {
  return switch (step) {
    CreatorWorkspaceStep.storySentences => 'Storytelling',
    CreatorWorkspaceStep.vocabulary => 'Semantics',
    CreatorWorkspaceStep.quiz => 'Quizzes',
    CreatorWorkspaceStep.grammar => 'Grammar',
    CreatorWorkspaceStep.listeningPronunciation => 'Listening',
    CreatorWorkspaceStep.storyBasics => 'Story',
  };
}

/// Step 2 — story body: primary plaintext editor + preview row actions + optional support meanings.
class StoryCreatorSentencesScreen extends ConsumerStatefulWidget {
  const StoryCreatorSentencesScreen({super.key});

  @override
  ConsumerState<StoryCreatorSentencesScreen> createState() =>
      _StoryCreatorSentencesScreenState();
}

class _StoryCreatorSentencesScreenState
    extends ConsumerState<StoryCreatorSentencesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressDrawerController;
  final _drawerPanSession = ValueNotifier<bool>(false);
  late final TextEditingController _body;
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _listScroll = ScrollController();
  int? _editingSentenceIndex;
  String? _editingSentenceId;
  bool _suspendBodySync = false;
  bool _managingFurigana = false;
  bool _composerActionBusy = false;
  bool _backNavigationInProgress = false;
  bool _seeded = false;
  Timer? _statsDebounce;
  Timer? _draftSyncDebounce;

  static const _hPad = 16.0;
  /// Rhythm: list ↔ composer and between sentence cards.
  static const _listBottomPad = 12.0;
  static const _cardGap = 12.0;
  static const _drawerAnimDuration = Duration(milliseconds: 240);

  /// Best-effort query params for the current route.
  ///
  /// During fast panel/module transitions, this widget can be in a deactivating
  /// state where inherited lookups (like `GoRouterState.of(context)`) throw
  /// "Looking up a deactivated widget's ancestor is unsafe." We prefer treating
  /// route data as unavailable in that frame over crashing.
  Map<String, String> _safeRouteQueryParams() {
    try {
      return GoRouterState.of(context).uri.queryParameters;
    } catch (_) {
      return const <String, String>{};
    }
  }

  void _dismissKeyboard() {
    // Be aggressive: some menus/dialogs can restore focus after closing.
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _body = TextEditingController();
    _body.addListener(_onBodyChanged);
    _progressDrawerController = AnimationController(
      vsync: this,
      duration: _drawerAnimDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_seeded) return;
      final d = ref.read(storyCreatorDraftDataProvider);
      _body.text = d.sentencesPlaintextDisplay;
      _seeded = true;
      if (mounted) setState(() {});
    });
  }

  void _onBodyChanged() {
    if (_suspendBodySync) return;
    _statsDebounce?.cancel();
    _statsDebounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() {});
    });
    _draftSyncDebounce?.cancel();
    _draftSyncDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(storyCreatorDraftProvider.notifier).applySentences(_body.text);
    });
  }

  List<String> _linesFromBody() =>
      List<String>.from(storyPlaintextNonEmptyLines(_body.text));

  void _applyLines(List<String> lines) {
    final next = lines.join('\n');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
  }

  /// New lines are always appended — list order is creation order until the user reorders.
  /// Scroll just enough to show the newest card; avoid long animated scrolls.
  void _scrollListAfterSentenceAdded() {
    if (!_listScroll.hasClients) return;
    final position = _listScroll.position;
    final target = position.maxScrollExtent;
    if (!target.isFinite || target <= 0) return;
    final distance = target - position.pixels;
    if (distance <= 2) return;
    if (distance < 120) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scheduleScrollAndComposerFocusAfterInsert() {
    var framesWaited = 0;
    void attempt() {
      if (!mounted) return;
      if (!_listScroll.hasClients) {
        framesWaited++;
        if (framesWaited > 12) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      _scrollListAfterSentenceAdded();
      if (!_composerFocus.hasFocus) {
        _composerFocus.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _enterEditAt(int index) {
    final lines = _linesFromBody();
    if (index < 0 || index >= lines.length) return;
    _dismissKeyboard();
    final draft = ref.read(storyCreatorDraftDataProvider);
    final sentenceId = (index < draft.sentences.length &&
            draft.sentences[index].japaneseText == lines[index])
        ? draft.sentences[index].id
        : null;
    setState(() {
      _editingSentenceIndex = index;
      _editingSentenceId = sentenceId;
      _managingFurigana = false;
    });
    _composer.text = lines[index];
    _composer.selection =
        TextSelection.collapsed(offset: _composer.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScroll.hasClients) return;
      _listScroll.animateTo(
        _listScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _cancelEdit() {
    _dismissKeyboard();
    setState(() {
      _editingSentenceIndex = null;
      _editingSentenceId = null;
    });
    _composer.clear();
    _managingFurigana = false;
  }

  static List<int> _allOccurrences(String text, String needle) {
    if (needle.isEmpty) return const [];
    final out = <int>[];
    var i = 0;
    while (true) {
      final j = text.indexOf(needle, i);
      if (j < 0) break;
      out.add(j);
      i = j + needle.length;
    }
    return out;
  }

  static bool _overlapsAny(List<FuriganaSpan> spans, int start, int end) {
    for (final s in spans) {
      if (!(s.end <= start || s.start >= end)) return true;
    }
    return false;
  }

  ({List<FuriganaSpan> kept, int removedCount}) _remapFuriganaSpans({
    required String oldText,
    required String newText,
    required List<FuriganaSpan> oldSpans,
  }) {
    final kept = <FuriganaSpan>[];
    var removed = 0;

    final sorted = oldSpans.where((s) => s.isValid).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final s in sorted) {
      if (s.start < 0 || s.end > oldText.length || s.end <= s.start) {
        removed++;
        continue;
      }
      final target = oldText.substring(s.start, s.end);
      final sameRangeOk = s.end <= newText.length &&
          s.start >= 0 &&
          s.end > s.start &&
          newText.substring(s.start, s.end) == target;
      if (sameRangeOk && !_overlapsAny(kept, s.start, s.end)) {
        kept.add(FuriganaSpan(start: s.start, end: s.end, reading: s.reading));
        continue;
      }

      final occ = _allOccurrences(newText, target);
      if (occ.isEmpty) {
        removed++;
        continue;
      }
      // Pick nearest occurrence to the old start, preferring non-overlapping.
      occ.sort((a, b) => (a - s.start).abs().compareTo((b - s.start).abs()));
      int? chosen;
      for (final o in occ) {
        final start = o;
        final end = o + target.length;
        if (end > newText.length) continue;
        if (_overlapsAny(kept, start, end)) continue;
        chosen = start;
        break;
      }
      if (chosen == null) {
        removed++;
        continue;
      }
      kept.add(
        FuriganaSpan(
          start: chosen,
          end: chosen + target.length,
          reading: s.reading,
        ),
      );
    }

    kept.sort((a, b) => a.start.compareTo(b.start));
    return (kept: kept, removedCount: removed);
  }

  void _saveEdit() {
    final index = _editingSentenceIndex;
    final sentenceId = _editingSentenceId;
    if (index == null) return;
    if (_composerActionBusy) return;

    final nextText = _composer.text.trim();
    final lines = _linesFromBody();
    if (index < 0 || index >= lines.length) {
      _cancelEdit();
      return;
    }

    final oldText = lines[index];
    if (nextText.isEmpty) {
      _deleteSentenceAt(index);
      _cancelEdit();
      return;
    }

    setState(() => _composerActionBusy = true);
    try {
      _dismissKeyboard();

      // Update the specific sentence, preserving furigana where possible.
      if (sentenceId != null) {
        final draft = ref.read(storyCreatorDraftDataProvider);
        final existing = draft.sentences.firstWhere(
          (s) => s.id == sentenceId,
          orElse: () => draft.sentences[index],
        );
        final oldSpans = existing.furiganaSpans;
        final remap = oldText == nextText
            ? (kept: List<FuriganaSpan>.from(oldSpans), removedCount: 0)
            : _remapFuriganaSpans(
                oldText: oldText,
                newText: nextText,
                oldSpans: oldSpans,
              );

        ref
            .read(storyCreatorDraftProvider.notifier)
            .updateSentenceTextAndFurigana(
              sentenceId: sentenceId,
              japaneseText: nextText,
              spans: remap.kept,
            );

        if (remap.removedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Some furigana were removed because the sentence changed.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Sync the plaintext view from the draft (avoid merge-by-text losing metadata).
      final nextDraft = ref.read(storyCreatorDraftDataProvider);
      _suspendBodySync = true;
      _body.text = nextDraft.sentencesPlaintextDisplay;
      _suspendBodySync = false;

      setState(() {
        _editingSentenceIndex = null;
        _editingSentenceId = null;
      });
      _composer.clear();
      _managingFurigana = false;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _composerActionBusy = false);
      });
    }
  }

  void _sendComposerLine() {
    if (_composerActionBusy) return;
    final t = _composer.text.trim();
    if (t.isEmpty) return;

    setState(() => _composerActionBusy = true);
    try {
      final lines = _linesFromBody();
      lines.add(t);
      _applyLines(lines);
      _composer.clear();

      // Immediately hydrate draft state so furigana/meanings stay in sync with the list.
      ref.read(storyCreatorDraftProvider.notifier).applySentences(_body.text);

      // Keep IME open for rapid back-to-back sentences; reveal the new card lightly.
      _scheduleScrollAndComposerFocusAfterInsert();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _composerActionBusy = false);
      });
    }
  }

  Future<void> _editSupportAt(int index) async {
    _dismissKeyboard();
    ref.read(storyCreatorDraftProvider.notifier).applySentences(_body.text);
    final lines = _linesFromBody();
    final draft = ref.read(storyCreatorDraftDataProvider);
    if (index < 0 || index >= draft.sentences.length || index >= lines.length) {
      return;
    }
    final s = draft.sentences[index];
    if (s.japaneseText != lines[index]) return;

    final result = await showModalBottomSheet<_SupportMeaningsResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _SupportMeaningsSheet(
          sentenceNumber: index + 1,
          japaneseText: s.japaneseText,
          furiganaSpans: s.furiganaSpans,
          initialSourceMeaning: s.meanings?.my ?? '',
          initialEnglishMeaning: s.meanings?.en ?? '',
        );
      },
    );

    if (!mounted || result == null) return;

    final nextMeanings = LocalizedMeanings.layerFromEnMy(
      enRaw: result.englishMeaning,
      myRaw: result.sourceMeaning,
      preserveExtrasFrom: s.meanings,
    );
    ref.read(storyCreatorDraftProvider.notifier).updateSentenceSupport(
          sentenceId: s.id,
          meanings: nextMeanings,
        );
    setState(() {});
  }

  void _deleteSentenceAt(int index) {
    final lines = _linesFromBody();
    if (index < 0 || index >= lines.length) return;
    lines.removeAt(index);
    _applyLines(lines);
    if (_editingSentenceIndex != null) {
      final editing = _editingSentenceIndex!;
      if (editing == index) {
        _cancelEdit();
      } else if (editing > index) {
        setState(() => _editingSentenceIndex = editing - 1);
      }
    }
  }

  void _reorderSentence(int oldIndex, int newIndex) {
    _dismissKeyboard();
    final lines = _linesFromBody();
    if (oldIndex < 0 || oldIndex >= lines.length) return;
    if (newIndex < 0 || newIndex > lines.length) return;

    var insertIndex = newIndex;
    if (oldIndex < insertIndex) {
      insertIndex -= 1;
    }
    final moved = lines.removeAt(oldIndex);
    lines.insert(insertIndex, moved);

    final next = lines.join('\n');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    ref.read(storyCreatorDraftProvider.notifier).applySentences(_body.text);

    final id = _editingSentenceId;
    if (id != null) {
      final draft = ref.read(storyCreatorDraftDataProvider);
      final idx = draft.sentences.indexWhere((s) => s.id == id);
      if (idx >= 0) {
        setState(() => _editingSentenceIndex = idx);
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _statsDebounce?.cancel();
    _draftSyncDebounce?.cancel();
    _body.removeListener(_onBodyChanged);
    _body.dispose();
    _composerFocus.dispose();
    _composer.dispose();
    _listScroll.dispose();
    _progressDrawerController.dispose();
    _drawerPanSession.dispose();
    super.dispose();
  }

  void _saveDraft() {
    _dismissKeyboard();
    ref.read(storyCreatorDraftProvider.notifier).applySentences(_body.text);
    unawaited(_saveToDiskAndToast());
  }

  Future<void> _saveToDiskAndToast() async {
    // Capture inherited dependencies synchronously; do not read inherited widgets
    // (e.g. GoRouterState/ScaffoldMessenger) after an async gap where this element
    // can become inactive during route transitions.
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(storyCreatorDraftProvider.notifier).globalSaveDraftNow();
    if (!mounted) return;
    final embed = ref.read(creatorDrawerSessionProvider).sentencesMainStep;
    if (learnModuleIdForWorkspaceLearnStep(embed) != null) {
      try {
        final st = router?.state;
        creatorNavDebug(
          'retain_embed',
          'drawer_save_draft host uri=${st?.uri} matchedLocation=${st?.matchedLocation} '
              'panel=${st?.uri.queryParameters['panel']} embed=$embed',
        );
      } catch (_) {}
      ref
          .read(creatorDrawerSessionProvider.notifier)
          .retainSentencesHostEmbeddedStep(
            embed,
            debugAction: 'drawer_save_draft',
          );
    }
    if (!mounted) return;
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('All changes saved locally.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showHowThisWorks() {
    _dismissKeyboard();
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
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How this works',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HowItWorksBullet(
                    text: 'Write one Japanese sentence at a time.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Tap send to add it to your story.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text:
                        'Tap a sentence to edit text, readings, and translations.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Reorder sentences anytime.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text:
                        'Publish Read Only or Full Learn from the progress menu when you are ready.',
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVocabHowTo() {
    _dismissKeyboard();
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
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to add vocabulary / kanji',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HowItWorksBullet(
                    text: 'Tap Add entry.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Select a word or phrase from the story.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Choose Vocabulary or Kanji.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Add source meaning first.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Optionally add English meaning.',
                    theme: theme,
                  ),
                  _HowItWorksBullet(
                    text: 'Optionally add up to 3 example sentences.',
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVocabReview() {
    _dismissKeyboard();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.read(storyCreatorDraftDataProvider);
    final items = draft.vocabularyKanji.entries;

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
                'Review created vocabulary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'} created so far.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(
                  'No vocabulary items yet. Tap “Add entry” to create one from the story.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                )
              else
                for (final e in items) ...[
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.termJapanese,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  e.type.displayLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            StoryCreatorVocabKanjiEditorScreen.glossStatusLine(
                                e),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  void _showQuizHowTo() {
    _dismissKeyboard();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to create quiz items',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Quiz types:\n'
                '- Vocabulary: word/meaning questions\n'
                '- Kanji: kanji reading/meaning questions\n'
                '- Grammar: pattern meaning/usage questions\n'
                '- Sentence: comprehension about a story sentence\n\n'
                'How to add:\n'
                '1. Pick a tab (type)\n'
                '2. Tap “Add quiz”\n'
                '3. Write a clear prompt/question\n'
                '4. Add 4 answer options (A–D)\n'
                '5. Choose the correct answer\n\n'
                'Explanations:\n'
                '- Source explanation is primary\n'
                '- English explanation is optional and hidden by default',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuizTestPlay() {
    _dismissKeyboard();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.read(storyCreatorDraftDataProvider);
    final tabIndex = ref.read(quizTabIndexProvider);
    final active = clampQuizEditorTabIndex(tabIndex);
    if (active != tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(quizTabIndexProvider.notifier).state = active;
        }
      });
    }
    final tabTitle = quizEditorTabLabel(active);
    final items = [
      for (final q in draft.quiz.entries)
        if (quizEntryMatchesEditorTab(q, active)) q,
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.63,
          minChildSize: 0.36,
          maxChildSize: 0.82,
          builder: (ctx, scrollController) {
            return _QuizTestPlaySheet(
              theme: theme,
              tabTitle: tabTitle,
              items: items,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void _showListeningHowTo() {
    _dismissKeyboard();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening / Pronunciation',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Attach one full-story audio file for listening practice.\n\n'
                'How to add audio:\n'
                '1. Tap “Upload audio”\n'
                '2. Choose one file (mp3, m4a, wav)\n'
                '3. Optionally set a display name\n'
                '4. Optionally set duration (seconds)\n\n'
                'Manage it anytime:\n'
                '- Replace: choose a new file\n'
                '- Remove: clears the attachment\n\n'
                'Notes:\n'
                '- Audio is optional for Reading Only\n'
                '- Full Learn completion may require audio (V1 rule)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showListeningPreview() {
    _dismissKeyboard();
    final draft = ref.read(storyCreatorDraftDataProvider);
    final asset = draft.audio.storyAudio;
    if (asset == null || asset.isValidV1 != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio attached yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
          child: _ListeningPreviewSheet(
            theme: theme,
            asset: asset,
          ),
        );
      },
    );
  }

  void _showReaderPreview() {
    _dismissKeyboard();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final draft = ref.read(storyCreatorDraftDataProvider);
    final sentences = List<StorySentenceItem>.from(draft.sentences)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

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
                'Preview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Read-only preview of how sentences will appear to readers.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (sentences.isEmpty)
                Text(
                  'No sentences yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                )
              else
                for (final s in sentences) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: cs.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NimonJapaneseSentenceLine(
                            text: s.japaneseText,
                            spans: s.furiganaSpans,
                            theme: theme,
                          ),
                          if (s.meanings != null) ...[
                            const SizedBox(height: 8),
                            if ((s.meanings?.my ?? '').trim().isNotEmpty)
                              Text(
                                s.meanings!.my!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            if ((s.meanings?.en ?? '').trim().isNotEmpty) ...[
                              if ((s.meanings?.my ?? '').trim().isNotEmpty)
                                const SizedBox(height: 6),
                              Text(
                                s.meanings!.en!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  void _showGrammarHowTo() {
    StoryCreatorGrammarOverlays.showHowTo(context);
  }

  void _showGrammarTestPlay() {
    StoryCreatorGrammarOverlays.showTestPlay(context, ref);
  }

  void _prepareWorkspaceNavigation() {
    _dismissKeyboard();
    if (_editingSentenceIndex != null) {
      _cancelEdit();
    }
  }

  /// Same query shape as [GoRouter.go] for the sentences host (avoid ad-hoc string concat
  /// / `https://…` parsing — empty [draftId] and `panel` must round-trip for [reportRoute]).
  Uri _sentencesHostDrawerUri({required String draftId, String? panel}) {
    final d = draftId.trim();
    final q = <String, String>{
      if (d.isNotEmpty) 'draftId': d,
      if (panel != null && panel.isNotEmpty) 'panel': panel,
    };
    return Uri(path: '/create/story/sentences', queryParameters: q);
  }

  /// [target] is the same [Uri] passed to [GoRouter.go]; session + sync dedupe follow via
  /// [syncCreatorDrawerSessionForResolvedLocation] so stale post-frame router sync cannot
  /// drop `?panel=` mid-navigation.
  ///
  /// Applies [syncCreatorDrawerSessionForResolvedLocation] synchronously after [go] so
  /// session matches the committed `go` target; dedupe keys in [creator_route_sync] are
  /// canonical so router post-frame sync cannot drop `?panel=` due to URI string mismatch.
  void _goStorySentencesFromDrawerUri(Uri target) {
    final router = GoRouter.maybeOf(context);
    context.go(target.toString());
    if (router == null) return;
    if (!mounted) return;
    syncCreatorDrawerSessionForResolvedLocation(router, ref, target);
  }

  void _openProgressDrawer() {
    _dismissKeyboard();
    _progressDrawerController.animateTo(
      1,
      duration: _drawerAnimDuration,
      curve: Curves.easeOutCubic,
    );
  }

  static String? _panelParamForStep(CreatorWorkspaceStep step) {
    return switch (step) {
      CreatorWorkspaceStep.vocabulary => 'vocabulary',
      CreatorWorkspaceStep.grammar => 'grammar',
      CreatorWorkspaceStep.quiz => 'quiz',
      CreatorWorkspaceStep.listeningPronunciation => 'listening',
      _ => null,
    };
  }

  Future<void> _closeProgressDrawer() async {
    await _progressDrawerController.animateTo(
      0,
      duration: _drawerAnimDuration,
      curve: Curves.easeInCubic,
    );
  }

  /// Centralized back policy (drawer, header, Android) — see [performCreatorBackFromSentencesHost].
  Future<void> _handleSentencesBackNavigation() async {
    if (_backNavigationInProgress) return;
    _backNavigationInProgress = true;
    try {
      if (kDebugMode) {
        var u = '(no_uri)';
        try {
          u = GoRouter.maybeOf(context)?.state.uri.toString() ?? u;
        } catch (_) {}
        debugPrint(
          '[NIMON_BACK_TRACE] StoryCreatorSentencesScreen policy back uri=$u '
          'drawerDismissed=${_progressDrawerController.isDismissed}',
        );
      }
      await handleCreatorBackPressed(
        context,
        ref,
        progressDrawerDismissed: _progressDrawerController.isDismissed,
        closeProgressDrawer: _closeProgressDrawer,
      );
    } finally {
      if (mounted) {
        _backNavigationInProgress = false;
      }
    }
  }

  Future<void> _handleSentencesBackWhileLoadingDraft() async {
    await performCreatorBackFromSentencesDraftLoading(
      context,
      progressDrawerDismissed: _progressDrawerController.isDismissed,
      closeProgressDrawer: _closeProgressDrawer,
    );
  }

  void _onDrawerDragStart() {
    _dismissKeyboard();
    _drawerPanSession.value = true;
  }

  void _onDrawerDragUpdate(double drawerW, DragUpdateDetails details) {
    final t = _progressDrawerController.value;
    if (t <= 0.0) return;
    final delta = details.delta.dx;
    if (delta == 0) return;
    final next =
        (_progressDrawerController.value - (delta / drawerW)).clamp(0.0, 1.0);
    _progressDrawerController.value = next;
  }

  void _snapDrawerAfterDrag(double drawerW, DragEndDetails details) {
    _snapDrawerFromDragEnd(details.primaryVelocity ?? 0.0);
  }

  /// [primaryVelocity] is horizontal (positive = rightward), same as [DragEndDetails.primaryVelocity].
  void _snapDrawerFromDragEnd(double primaryVelocity) {
    _drawerPanSession.value = false;
    final v = primaryVelocity;
    final t = _progressDrawerController.value;
    if (v.abs() > 600) {
      if (v > 0) {
        unawaited(_closeProgressDrawer());
      } else {
        _openProgressDrawer();
      }
      return;
    }
    if (t >= 0.5) {
      _openProgressDrawer();
    } else {
      unawaited(_closeProgressDrawer());
    }
  }

  List<String?> _supportLabels(
      List<String> lines, List<StorySentenceItem> sentences) {
    return [
      for (var i = 0; i < lines.length; i++)
        if (i < sentences.length && sentences[i].japaneseText == lines[i])
          sentences[i].supportMeaningsSummaryV1
        else
          null,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 1) Never touch [ref] / inherited lookup until we know the global location
    //    is still under /create/story. Otherwise after go(/mono) the last build
    //    can run on a deactivating context and triggers inactive-element asserts.
    // 2) Do not log with [ref] here — that still schedules work before the guard.
    if (!mounted) return const SizedBox.shrink();
    try {
      final r = GoRouter.maybeOf(context);
      if (r == null || !r.state.uri.path.startsWith('/create/story')) {
        return const SizedBox.shrink();
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    final qp = _safeRouteQueryParams();
    final routeDraftId = qp['draftId'];
    final cleanedRouteId = (routeDraftId == null || routeDraftId.trim().isEmpty)
        ? null
        : routeDraftId.trim();
    final loadedDraft = ref.watch(storyCreatorDraftDataProvider);
    if (cleanedRouteId != null && loadedDraft.id != cleanedRouteId) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          unawaited(_handleSentencesBackWhileLoadingDraft());
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Story sentences'),
            leading: NimonBackButton(
              onPressed: () {
                unawaited(_handleSentencesBackWhileLoadingDraft());
              },
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final lines = storyPlaintextNonEmptyLines(_body.text);
    final count = lines.length;
    final draft = loadedDraft;
    // Same merge [applySentences] uses: stable ids per plaintext line even when
    // Riverpod has not applied the last body edit yet (reorder/web frame timing).
    final sentenceRowMergePreview = storySentencesFromPlaintextMerge(
      storyId: draft.id,
      plain: _body.text,
      previous: draft.sentences,
    );
    final supportLabels = _supportLabels(lines, sentenceRowMergePreview);
    final isEditing = _editingSentenceIndex != null;

    final session = ref.watch(creatorDrawerSessionProvider);
    final routePanelStep =
        creatorWorkspaceStepForSentencesPanel(qp['panel']);
    // V1: on this host, router `?panel=` (or absence = main storytelling) is canonical
    // for the embedded module; session is reconciled from the same URI in [syncCreatorDrawerSessionForRouter].
    final effectiveStep =
        routePanelStep ?? CreatorWorkspaceStep.storySentences;
    final progress = buildCreatorDrawerProgressModel(draft: draft);
    final publishModel = buildStoryReviewDisplayModel(draft);
    final draftState = ref.watch(storyCreatorDraftProvider);
    final roSig = draftState.readOnlyPublishedCoreSig;
    final roExists =
        roSig != null || draft.publishState != StoryPublishState.draft;
    final roDirty = roSig != null &&
        computeReadOnlyPublishedCoreSignature(draft) != roSig;
    final flExists =
        draft.publishState == StoryPublishState.fullLearnPublished;
    final flDirty = draftState.dirty;
    final showSentencesWorkspace =
        effectiveStep == CreatorWorkspaceStep.storySentences;
    final inVocabularyModule = effectiveStep == CreatorWorkspaceStep.vocabulary;
    final inGrammarModule = effectiveStep == CreatorWorkspaceStep.grammar;
    final inQuizModule = effectiveStep == CreatorWorkspaceStep.quiz;
    final inListeningModule =
        effectiveStep == CreatorWorkspaceStep.listeningPronunciation;
    final pinnedTitle = _pinnedWorkspaceTitle(effectiveStep);
    creatorNavDebug(
      'body_fragment',
      '[body_fragment] rendered=$effectiveStep routePanelStep=$routePanelStep '
          'activeModule=${session.activeModule} panel=${qp['panel']}',
    );
    // Spacing tune (V1): keep the first content comfortably below the floating
    // glass header cluster (cards should feel like they slide underneath it).
    final listTopPad = (mq.padding.top + 56 + 22).clamp(82, 128).toDouble();

    final listBottomPad =
        _listBottomPad + (mq.padding.bottom > 0 ? 4.0 : 0.0);

    // Visible title lives in the floating glass header (premium chat-style).

    final basePage = Stack(
      children: [
        GestureDetector(
          // Let list items / reorder handles receive pointer gestures first.
          behavior: HitTestBehavior.deferToChild,
          onTap: _dismissKeyboard,
          child: Column(
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        // Keep the first card fully below the floating header/back button.
                        padding: EdgeInsets.fromLTRB(
                          _hPad,
                          listTopPad,
                          _hPad,
                          0,
                        ),
                        child: !showSentencesWorkspace
                            ? CreatorWorkspaceModulePlaceholder(
                                key: ValueKey(effectiveStep),
                                step: effectiveStep,
                                topPadding: 0,
                              )
                            : count == 0
                                ? CustomScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    slivers: [
                                      SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: listBottomPad,
                                          ),
                                          child: _EmptySentencesState(
                                            theme: theme,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ReorderableListView.builder(
                                    scrollController: _listScroll,
                                    buildDefaultDragHandles: false,
                                    dragStartBehavior: DragStartBehavior.down,
                                    padding: EdgeInsets.only(
                                      bottom: listBottomPad,
                                    ),
                                    proxyDecorator: (child, index, animation) {
                                      return AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, _) {
                                          final t = Curves.easeOut.transform(
                                            animation.value,
                                          );
                                          return Material(
                                            color: Colors.transparent,
                                            elevation: lerpDouble(0, 8, t) ?? 0,
                                            shadowColor: Colors.black
                                                .withValues(alpha: 0.18 * t),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: child,
                                          );
                                        },
                                      );
                                    },
                                    itemCount: lines.length,
                                    onReorder: _reorderSentence,
                                    itemBuilder: (context, i) {
                                      final label = i < supportLabels.length
                                          ? supportLabels[i]
                                          : null;
                                      final s = i < sentenceRowMergePreview.length
                                          ? sentenceRowMergePreview[i]
                                          : null;
                                      final spans = (s != null &&
                                              s.japaneseText == lines[i])
                                          ? s.furiganaSpans
                                          : const <FuriganaSpan>[];
                                      return Padding(
                                        key: ValueKey<String>(
                                          i < sentenceRowMergePreview.length
                                              ? sentenceRowMergePreview[i].id
                                              : 'sentence_row_$i',
                                        ),
                                        padding: EdgeInsets.only(
                                          bottom: i < lines.length - 1
                                              ? _cardGap
                                              : 0,
                                        ),
                                        child: _SentenceComposerItem(
                                          index: i,
                                          japaneseText: lines[i],
                                          furiganaSpans: spans,
                                          supportSummary: label,
                                          theme: theme,
                                          onTranslate: () {
                                            _dismissKeyboard();
                                            _editSupportAt(i);
                                          },
                                          onEdit: () {
                                            _dismissKeyboard();
                                            _enterEditAt(i);
                                          },
                                          onMoreOpened: _dismissKeyboard,
                                          onMoreCanceled: _dismissKeyboard,
                                          onDelete: () {
                                            _dismissKeyboard();
                                            _deleteSentenceAt(i);
                                          },
                                          reorderDragStartListener:
                                              ReorderableDragStartListener(
                                            index: i,
                                            child: CreatorReorderHandle(
                                              theme: theme,
                                              semanticsLabel: 'Reorder sentence',
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showSentencesWorkspace)
                // Isolate composer rebuilds: typing/selection updates the controller only;
                // sentence list does not rebuild on each keystroke.
                ListenableBuilder(
                  listenable: _composer,
                  builder: (context, _) {
                    return _BottomComposer(
                      theme: theme,
                      controller: _composer,
                      focusNode: _composerFocus,
                      isActionBusy: _composerActionBusy,
                      isEditing: isEditing,
                      editingSentenceNumber:
                          isEditing ? (_editingSentenceIndex! + 1) : null,
                      onCancelEdit: isEditing ? _cancelEdit : null,
                      onSubmit: () {
                        if (_editingSentenceIndex != null) {
                          _saveEdit();
                        } else {
                          _sendComposerLine();
                        }
                      },
                      canManageFurigana:
                          isEditing && (_editingSentenceId != null),
                      managingFurigana: _managingFurigana,
                      onOpenManageFurigana: () {
                        if (!isEditing || _editingSentenceId == null) return;
                        setState(() => _managingFurigana = true);
                      },
                      onExitManageFurigana: () {
                        setState(() => _managingFurigana = false);
                      },
                      furiganaManagePanel: (isEditing &&
                              _managingFurigana &&
                              _editingSentenceId != null)
                          ? _buildFuriganaManagePanel(theme)
                          : null,
                    );
                  },
                ),
            ],
          ),
        ),
        // Subtle top fade/blur mask so cards feel like they slide behind the
        // floating glass header (premium chat-style).
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(
                  height: (mq.padding.top + 84).clamp(84, 120).toDouble(),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.78),
                        theme.colorScheme.surface.withValues(alpha: 0.48),
                        theme.colorScheme.surface.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Pinned overlay: never part of the scrollable column; always above list content.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _FloatingPillHeader(
                title: pinnedTitle,
                onTapBack: () {
                  unawaited(_handleSentencesBackNavigation());
                },
                onTapPrimaryAction: inVocabularyModule
                    ? _showVocabReview
                    : (inGrammarModule
                        ? _showGrammarTestPlay
                        : (inQuizModule
                            ? _showQuizTestPlay
                            : (inListeningModule
                                ? _showListeningPreview
                                : _showReaderPreview))),
                onTapHelp: inVocabularyModule
                    ? _showVocabHowTo
                    : (inGrammarModule
                        ? _showGrammarHowTo
                        : (inQuizModule
                            ? _showQuizHowTo
                            : (inListeningModule
                                ? _showListeningHowTo
                                : _showHowThisWorks))),
                onTapMenu: _openProgressDrawer,
                primaryIcon: inVocabularyModule
                    ? Icons.fact_check_outlined
                    : (inGrammarModule
                        ? Icons.fact_check_outlined
                        : (inQuizModule
                            ? Icons.play_circle_outline_rounded
                            : (inListeningModule
                                ? Icons.headphones_rounded
                                : Icons.remove_red_eye_outlined))),
                primaryTooltip: inVocabularyModule
                    ? 'Review created vocabulary'
                    : (inGrammarModule
                        ? 'Test-play grammar'
                        : (inQuizModule
                            ? 'Test-play quiz'
                            : (inListeningModule
                                ? 'Listening preview'
                                : 'Preview story'))),
                helpIcon: inVocabularyModule
                    ? Icons.help_outline_rounded
                    : (inGrammarModule
                        ? Icons.help_outline_rounded
                        : Icons.info_outline_rounded),
                helpTooltip: inVocabularyModule
                    ? 'How to add vocabulary / kanji'
                    : (inGrammarModule
                        ? 'How to create Grammar patterns'
                        : (inQuizModule
                            ? 'How to create quiz items'
                            : (inListeningModule
                                ? 'How to add audio'
                                : 'How this works'))),
              ),
            ),
          ),
        ),
      ],
    );

    return CreatorRouteSyncListener(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          unawaited(_handleSentencesBackNavigation());
        },
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          resizeToAvoidBottomInset: false,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final drawerW = (maxW * 0.78).clamp(280.0, 360.0);

              return AnimatedBuilder(
                animation: _progressDrawerController,
                child: basePage,
                builder: (context, child) {
                final t = _progressDrawerController.value;
                final showDrawer = t > 0.001 || _drawerPanSession.value;
                final enableDrawerDrag = showDrawer;
                final drawerDx = drawerW * (1.0 - t);
                final pageDx = -drawerW * t;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background behind the pushed page (prevents default black showing).
                    Positioned.fill(
                      child: ColoredBox(
                        color: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),

                    // Story page (pushes left while the drawer opens).
                    Transform.translate(
                      offset: Offset(pageDx, 0),
                      child: IgnorePointer(
                        ignoring: showDrawer,
                        child: child!,
                      ),
                    ),

                    // Backdrop blocks underlying page while open and supports tap-to-close.
                    if (showDrawer)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => unawaited(_closeProgressDrawer()),
                          onHorizontalDragStart:
                              enableDrawerDrag ? (_) => _onDrawerDragStart() : null,
                          onHorizontalDragUpdate: enableDrawerDrag
                              ? (d) => _onDrawerDragUpdate(drawerW, d)
                              : null,
                          onHorizontalDragEnd: enableDrawerDrag
                              ? (d) => _snapDrawerAfterDrag(drawerW, d)
                              : null,
                          onHorizontalDragCancel: enableDrawerDrag
                              ? () => _drawerPanSession.value = false
                              : null,
                        ),
                      ),

                    // Side drawer panel slides over the page.
                    if (showDrawer)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: drawerW,
                        child: Transform.translate(
                          offset: Offset(drawerDx, 0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: enableDrawerDrag
                                ? (_) => _onDrawerDragStart()
                                : null,
                            onHorizontalDragUpdate: enableDrawerDrag
                                ? (d) => _onDrawerDragUpdate(drawerW, d)
                                : null,
                            onHorizontalDragEnd: enableDrawerDrag
                                ? (d) => _snapDrawerAfterDrag(drawerW, d)
                                : null,
                            onHorizontalDragCancel: enableDrawerDrag
                                ? () => _drawerPanSession.value = false
                                : null,
                            child: Material(
                              color: theme.colorScheme.surfaceContainerLow,
                              child: SafeArea(
                                bottom: true,
                                top: true,
                                left: false,
                                right: true,
                                child: SizedBox.expand(
                                  child: CreatorProgressDrawer(
                                    drawerKeySlot:
                                        kCreatorProgressDrawerKeySentences,
                                    coreItems: progress.coreItems,
                                    learnItems: progress.learnItems,
                                    publishModel: publishModel,
                                    readOnlyPublishedExists: roExists,
                                    readOnlyHasUnpublishedChanges: roDirty,
                                    fullLearnPublishedExists: flExists,
                                    fullLearnHasUnpublishedChanges: flDirty,
                                    learnModeEnabled: session.learnModeEnabled,
                                    currentStepId:
                                        creatorEffectiveActiveStep(session),
                                    onLearnModeChanged: (v) {
                                      applyCreatorLearnMode(
                                        context: context,
                                        ref: ref,
                                        learnModeEnabled: v,
                                        closeDrawerOnTurnOff: () =>
                                            unawaited(_closeProgressDrawer()),
                                      );
                                    },
                                    onOpenStep: (route) {
                                              final draftId = ref
                                                  .read(
                                                      storyCreatorDraftDataProvider)
                                                  .id;
                                              final beforeUri = () {
                                                try {
                                                  return GoRouterState.of(context)
                                                      .uri
                                                      .toString();
                                                } catch (_) {
                                                  return '(no_go_router)';
                                                }
                                              }();
                                              final beforeSession = ref.read(
                                                  creatorDrawerSessionProvider);
                                              creatorNavDebug(
                                                'drawer_module_tap',
                                                'tap route=$route | beforeUri=$beforeUri | '
                                                'before activeModule=${beforeSession.activeModule} '
                                                'before step=${beforeSession.sentencesMainStep}',
                                              );
                                              final step =
                                                  creatorWorkspaceStepForDrawerRoute(
                                                      route);
                                              if (step ==
                                                  CreatorWorkspaceStep.storyBasics) {
                                                context.push('$route?draftId=$draftId');
                                                creatorNavDebug(
                                                  'drawer_module_tap',
                                                  'nav PUSH basics route=$route',
                                                );
                                                unawaited(_closeProgressDrawer());
                                                return;
                                              }
                                              if (step != null) {
                                                _prepareWorkspaceNavigation();
                                                // Router is canonical; mirror the exact `go` target into session
                                                // immediately and again post-frame (see [_goStorySentencesFromDrawerUri]).
                                                final panel =
                                                    _panelParamForStep(step);
                                                if (panel != null) {
                                                  _goStorySentencesFromDrawerUri(
                                                    _sentencesHostDrawerUri(
                                                      draftId: draftId,
                                                      panel: panel,
                                                    ),
                                                  );
                                                  creatorNavDebug(
                                                    'drawer_module_tap',
                                                    'nav URL_SYNC panel=$panel',
                                                  );
                                                } else if (step ==
                                                    CreatorWorkspaceStep.storySentences) {
                                                  _goStorySentencesFromDrawerUri(
                                                    _sentencesHostDrawerUri(
                                                      draftId: draftId,
                                                    ),
                                                  );
                                                  creatorNavDebug(
                                                    'drawer_module_tap',
                                                    'nav URL_SYNC panel=(none)',
                                                  );
                                                }
                                                final afterSession = ref.read(
                                                    creatorDrawerSessionProvider);
                                                creatorNavDebug(
                                                  'drawer_module_tap',
                                                  'nav EMBED step=$step | after activeModule=${afterSession.activeModule} '
                                                  'after step=${afterSession.sentencesMainStep}',
                                                );
                                                unawaited(_closeProgressDrawer());
                                                return;
                                              }
                                              context.push(route);
                                              creatorNavDebug(
                                                'drawer_module_tap',
                                                'nav PUSH fallback route=$route',
                                              );
                                              unawaited(_closeProgressDrawer());
                                            },
                                            onSaveDraft: () {
                                              unawaited(_closeProgressDrawer());
                                              _saveDraft();
                                            },
                                            onPublish: (mode) async {
                                              unawaited(_closeProgressDrawer());
                                              await performCreatorDrawerPublish(
                                                ref: ref,
                                                context: context,
                                                mode: mode,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                  ],
                );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _syncBodyFromDraft() {
    final nextDraft = ref.read(storyCreatorDraftDataProvider);
    _suspendBodySync = true;
    _body.text = nextDraft.sentencesPlaintextDisplay;
    _suspendBodySync = false;
  }

  StorySentenceItem? _sentenceById(String sentenceId) {
    for (final s in ref.read(storyCreatorDraftDataProvider).sentences) {
      if (s.id == sentenceId) return s;
    }
    return null;
  }

  List<FuriganaSpan> _furiganaSpansForComposer(String sentenceId) {
    final s = _sentenceById(sentenceId);
    if (s == null) return const [];
    final jp = _composer.text;
    if (s.japaneseText == jp) {
      return List<FuriganaSpan>.from(s.furiganaSpans);
    }
    return _remapFuriganaSpans(
      oldText: s.japaneseText,
      newText: jp,
      oldSpans: s.furiganaSpans,
    ).kept;
  }

  void _commitSentenceTextAndFurigana({
    required String sentenceId,
    required List<FuriganaSpan> spans,
  }) {
    ref.read(storyCreatorDraftProvider.notifier).updateSentenceTextAndFurigana(
          sentenceId: sentenceId,
          japaneseText: _composer.text.trim(),
          spans: spans,
        );
    _syncBodyFromDraft();
    final updated = _sentenceById(sentenceId);
    if (updated != null) {
      _composer.text = updated.japaneseText;
      _composer.selection =
          TextSelection.collapsed(offset: _composer.text.length);
    }
  }

  Widget _buildFuriganaManagePanel(ThemeData theme) {
    final sid = _editingSentenceId;
    if (sid == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: _FuriganaManageInlinePanel(
        key: ValueKey<String>('furigana-$sid'),
        theme: theme,
        japaneseText: _composer.text,
        spans: _furiganaSpansForComposer(sid),
        onApplyFurigana: (next) =>
            _commitSentenceTextAndFurigana(sentenceId: sid, spans: next),
      ),
    );
  }
}

class _SupportMeaningsResult {
  const _SupportMeaningsResult({
    required this.sourceMeaning,
    required this.englishMeaning,
  });

  final String sourceMeaning;
  final String englishMeaning;
}

class _SupportMeaningsSheet extends StatefulWidget {
  const _SupportMeaningsSheet({
    required this.sentenceNumber,
    required this.japaneseText,
    required this.furiganaSpans,
    required this.initialSourceMeaning,
    required this.initialEnglishMeaning,
  });

  final int sentenceNumber;
  final String japaneseText;
  final List<FuriganaSpan> furiganaSpans;
  final String initialSourceMeaning;
  final String initialEnglishMeaning;

  @override
  State<_SupportMeaningsSheet> createState() => _SupportMeaningsSheetState();
}

class _SupportMeaningsSheetState extends State<_SupportMeaningsSheet> {
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _enCtrl;

  @override
  void initState() {
    super.initState();
    _sourceCtrl = TextEditingController(text: widget.initialSourceMeaning);
    _enCtrl = TextEditingController(text: widget.initialEnglishMeaning);
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final mq = MediaQuery.of(context);

    InputDecoration meaningFieldDeco({String? hint}) => InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          filled: true,
          fillColor: cs.surface,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        );

    TextStyle labelStyle() =>
        t.textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ) ??
        TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support meanings',
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sentence ${widget.sentenceNumber}',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Japanese sentence',
                      style: labelStyle(),
                    ),
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: NimonJapaneseSentenceLine(
                          text: widget.japaneseText,
                          spans: widget.furiganaSpans,
                          theme: t,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Source meaning',
                      style: labelStyle(),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _sourceCtrl,
                      decoration: meaningFieldDeco(
                        hint: 'Add a gloss in your source language',
                      ),
                      minLines: 2,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),
                    Theme(
                      data: t.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'English meaning (optional)',
                          style: t.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        initiallyExpanded: false,
                        children: [
                          const SizedBox(height: 8),
                          TextField(
                            controller: _enCtrl,
                            decoration: meaningFieldDeco(
                              hint: 'Optional English gloss',
                            ),
                            minLines: 2,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                math.max(12, mq.padding.bottom),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop<_SupportMeaningsResult?>(context, null),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop<_SupportMeaningsResult?>(
                      context,
                      _SupportMeaningsResult(
                        sourceMeaning: _sourceCtrl.text,
                        englishMeaning: _enCtrl.text,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Furigana “manage” UI: local state so typing in the reading field does not
/// rebuild the whole Storytelling screen.
class _FuriganaManageInlinePanel extends StatefulWidget {
  const _FuriganaManageInlinePanel({
    super.key,
    required this.theme,
    required this.japaneseText,
    required this.spans,
    required this.onApplyFurigana,
  });

  final ThemeData theme;
  final String japaneseText;
  final List<FuriganaSpan> spans;
  final void Function(List<FuriganaSpan> newSpans) onApplyFurigana;

  @override
  State<_FuriganaManageInlinePanel> createState() =>
      _FuriganaManageInlinePanelState();
}

class _FuriganaManageInlinePanelState
    extends State<_FuriganaManageInlinePanel> {
  late final TextEditingController _readingCtrl;
  ({int start, int end})? _selectedRange;
  String _sliceAtSelection = '';

  @override
  void initState() {
    super.initState();
    _readingCtrl = TextEditingController();
    _readingCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _readingCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FuriganaManageInlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.japaneseText != widget.japaneseText &&
        _selectedRange != null) {
      final r = _selectedRange!;
      if (r.end > widget.japaneseText.length) {
        _clearEditor();
        return;
      }
      final slice = widget.japaneseText.substring(r.start, r.end);
      if (slice != _sliceAtSelection) {
        _clearEditor();
      }
    }
  }

  void _clearEditor() {
    _selectedRange = null;
    _readingCtrl.clear();
    _sliceAtSelection = '';
    if (mounted) setState(() {});
  }

  bool _spanOverlapsRange(int start, int end, List<FuriganaSpan> spans) {
    for (final f in spans.where((s) => s.isValid)) {
      if (!(f.end <= start || f.start >= end)) return true;
    }
    return false;
  }

  List<FuriganaSpan> _mergedForRange(
    List<FuriganaSpan> base,
    int start,
    int end,
    String reading,
  ) {
    final next = List<FuriganaSpan>.from(base)
      ..removeWhere((f) => !(f.end <= start || f.start >= end))
      ..add(FuriganaSpan(start: start, end: end, reading: reading))
      ..sort((a, b) => a.start.compareTo(b.start));
    return next;
  }

  void _onKanjiTap(StoryFuriganaToken t) {
    if (!t.isKanjiTappable) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final exact = readingForExactTokenRange(widget.spans, t.start, t.end);
    setState(() {
      _selectedRange = (start: t.start, end: t.end);
      _sliceAtSelection = t.text;
      _readingCtrl.text = (exact ?? '').trim();
      _readingCtrl.selection =
          TextSelection.collapsed(offset: _readingCtrl.text.length);
    });
  }

  void _cancel() {
    FocusManager.instance.primaryFocus?.unfocus();
    _clearEditor();
  }

  void _save() {
    final r = _selectedRange;
    if (r == null) return;
    final reading = _readingCtrl.text.trim();
    if (reading.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final next = _mergedForRange(widget.spans, r.start, r.end, reading);
    widget.onApplyFurigana(next);
    _clearEditor();
  }

  void _remove() {
    final r = _selectedRange;
    if (r == null) return;
    if (!_spanOverlapsRange(r.start, r.end, widget.spans)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final next = widget.spans
        .where((f) => f.end <= r.start || f.start >= r.end)
        .toList();
    widget.onApplyFurigana(next);
    _clearEditor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final cs = theme.colorScheme;
    final text = widget.japaneseText;
    final spans = widget.spans;
    final tokens = splitStoryTextIntoFuriganaTokens(text);
    final hasKanjiTarget =
        tokens.any((StoryFuriganaToken x) => x.isKanjiTappable);
    final sel = _selectedRange;
    final canSave = sel != null && _readingCtrl.text.trim().isNotEmpty;
    final canRemove =
        sel != null && _spanOverlapsRange(sel.start, sel.end, spans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasKanjiTarget)
          Text(
            'Tap a kanji word to add reading.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.25,
            ),
          )
        else
          Text(
            'No kanji tokens available for furigana editing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        const SizedBox(height: 8),
        NimonJapaneseSentenceLine(
          text: text,
          spans: spans,
          theme: theme,
        ),
        if (hasKanjiTarget) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final t in tokens)
                _FuriganaTokenChip(
                  token: t,
                  theme: theme,
                  exactReading:
                      readingForExactTokenRange(spans, t.start, t.end),
                  selected:
                      sel != null && sel.start == t.start && sel.end == t.end,
                  onKanjiTap: _onKanjiTap,
                ),
            ],
          ),
        ],
        if (sel != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _readingCtrl,
            decoration: InputDecoration(
              labelText: 'Furigana',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              filled: true,
              fillColor: cs.surface,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSave) _save();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: canRemove ? _remove : null,
                child: const Text('Remove'),
              ),
              FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FuriganaTokenChip extends StatelessWidget {
  const _FuriganaTokenChip({
    required this.token,
    required this.theme,
    required this.exactReading,
    required this.selected,
    required this.onKanjiTap,
  });

  final StoryFuriganaToken token;
  final ThemeData theme;
  final String? exactReading;
  final bool selected;
  final void Function(StoryFuriganaToken t) onKanjiTap;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final t = token;
    final reading = (exactReading ?? '').trim();
    final showRuby = reading.isNotEmpty;

    final child = showRuby
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                reading,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: t.isKanjiTappable
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.52),
                ),
              ),
            ],
          )
        : Text(
            t.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.isKanjiTappable
                  ? cs.onSurface
                  : cs.onSurfaceVariant.withValues(alpha: 0.52),
            ),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: t.isKanjiTappable ? () => onKanjiTap(t) : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              width: selected ? 1.1 : 1,
              color: selected
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(
                      alpha: t.isKanjiTappable ? 0.42 : 0.22,
                    ),
            ),
            color: selected
                ? cs.surfaceContainerHighest.withValues(alpha: 0.52)
                : cs.surfaceContainerHighest.withValues(
                    alpha: t.isKanjiTappable ? 0.26 : 0.08,
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// (Save draft / publish are available via the progress drawer.)

class _FloatingPillHeader extends StatelessWidget {
  const _FloatingPillHeader({
    required this.title,
    required this.onTapBack,
    required this.onTapMenu,
    required this.onTapPrimaryAction,
    required this.onTapHelp,
    required this.primaryIcon,
    required this.primaryTooltip,
    required this.helpIcon,
    required this.helpTooltip,
  });

  final String title;
  final VoidCallback onTapBack;
  final VoidCallback onTapMenu;
  final VoidCallback onTapPrimaryAction;
  final VoidCallback onTapHelp;
  final IconData primaryIcon;
  final String primaryTooltip;
  final IconData helpIcon;
  final String helpTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget icon({
      Key? key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      return IconButton(
        key: key,
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 22, color: cs.onSurface),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
    }

    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
        height: 1.2,
      ),
    );

    return Row(
      children: [
        NimonCircleNavButton(
          onPressed: onTapBack,
          tooltip: 'Back',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: titleText,
          ),
        ),
        _GlassPillSurface(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onTap: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon(
                icon: primaryIcon,
                tooltip: primaryTooltip,
                onTap: onTapPrimaryAction,
              ),
              icon(
                icon: helpIcon,
                tooltip: helpTooltip,
                onTap: onTapHelp,
              ),
              icon(
                key: const ValueKey<String>('creator_progress_open_button'),
                icon: Icons.menu_rounded,
                tooltip: 'Progress',
                onTap: onTapMenu,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassPillSurface extends StatelessWidget {
  const _GlassPillSurface({
    required this.height,
    required this.child,
    this.padding,
    this.onTap,
  });

  final double height;
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final content = SizedBox(
      height: height,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: child),
      ),
    );

    final surface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.72),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.10),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  borderRadius: radius,
                  onTap: onTap,
                  child: content,
                ),
        ),
      ),
    );

    return surface;
  }
}

class _EmptySentencesState extends StatelessWidget {
  const _EmptySentencesState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant.withValues(alpha: 0.78);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 32,
                color: cs.onSurfaceVariant.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 16),
              Text(
                'No sentences yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  height: 1.25,
                  color: cs.onSurface.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a sentence below, then tap send.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceComposerItem extends StatelessWidget {
  const _SentenceComposerItem({
    required this.index,
    required this.japaneseText,
    required this.furiganaSpans,
    required this.supportSummary,
    required this.theme,
    required this.onTranslate,
    required this.onEdit,
    required this.onMoreOpened,
    required this.onMoreCanceled,
    required this.onDelete,
    required this.reorderDragStartListener,
  });

  final int index;
  final String japaneseText;
  final List<FuriganaSpan> furiganaSpans;
  final String? supportSummary;
  final ThemeData theme;
  final VoidCallback onTranslate;
  final VoidCallback onEdit;
  final VoidCallback onMoreOpened;
  final VoidCallback onMoreCanceled;
  final VoidCallback onDelete;
  final Widget reorderDragStartListener;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final status = (supportSummary ?? '').trim().isEmpty
        ? 'No translation'
        : supportSummary!;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: NimonJapaneseSentenceLine(
                                  text: japaneseText,
                                  spans: furiganaSpans,
                                  theme: theme,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<_SentenceMoreAction>(
                        tooltip: 'More',
                        padding: EdgeInsets.zero,
                        offset: const Offset(0, 4),
                        onOpened: onMoreOpened,
                        onCanceled: onMoreCanceled,
                        onSelected: (a) {
                          if (a == _SentenceMoreAction.delete) {
                            onDelete();
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: _SentenceMoreAction.delete,
                            child: Text(
                              'Delete',
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        ],
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 22,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.82),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: onTranslate,
                              icon: const Icon(Icons.translate_outlined,
                                  size: 18),
                              label: const Text('Translate'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      reorderDragStartListener,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SentenceMoreAction { delete }

class _BottomComposer extends StatelessWidget {
  const _BottomComposer({
    required this.theme,
    required this.controller,
    required this.focusNode,
    required this.isActionBusy,
    required this.onSubmit,
    required this.isEditing,
    required this.editingSentenceNumber,
    required this.onCancelEdit,
    required this.canManageFurigana,
    required this.managingFurigana,
    required this.onOpenManageFurigana,
    required this.onExitManageFurigana,
    this.furiganaManagePanel,
  });

  final ThemeData theme;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isActionBusy;
  final VoidCallback onSubmit;
  final bool isEditing;
  final int? editingSentenceNumber;
  final VoidCallback? onCancelEdit;
  final bool canManageFurigana;
  final bool managingFurigana;
  final VoidCallback onOpenManageFurigana;
  final VoidCallback onExitManageFurigana;
  final Widget? furiganaManagePanel;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final inputText = controller.text.trim();
    final canSend = inputText.isNotEmpty && !isActionBusy;

    // Instant padding with keyboard inset — avoid animating insets (doubles OS keyboard motion).
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, math.max(8, bottom)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditing && editingSentenceNumber != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: cs.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Editing sentence $editingSentenceNumber',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onCancelEdit,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: cs.onPrimaryContainer,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      if (canManageFurigana) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: managingFurigana
                                ? onExitManageFurigana
                                : onOpenManageFurigana,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: cs.onPrimaryContainer,
                            ),
                            child: Text(
                              managingFurigana ? 'Done' : 'Furigana',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (furiganaManagePanel != null) ...[
                furiganaManagePanel!,
                const SizedBox(height: 12),
              ],
              AnimatedBuilder(
                animation: focusNode,
                builder: (context, _) {
                  final focused = focusNode.hasFocus;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: focused
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.52)
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.42),
                        border: Border.all(
                          width: focused ? 1.5 : 1,
                          color: focused
                              ? cs.primary.withValues(alpha: 0.38)
                              : cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 2, bottom: 10),
                              child: Semantics(
                                label: isEditing
                                    ? 'Editing sentence'
                                    : 'New sentence',
                                child: Icon(
                                  isEditing
                                      ? Icons.edit_outlined
                                      : Icons.short_text_rounded,
                                  size: 22,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: focused ? 0.62 : 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                  maxHeight: 120,
                                ),
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    hintText: isEditing
                                        ? 'Revise this sentence'
                                        : 'Add one Japanese sentence',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                  ),
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) {
                                    if (canSend) onSubmit();
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 2, bottom: 2),
                              child: IconButton.filled(
                                onPressed: canSend ? onSubmit : null,
                                style: IconButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(10),
                                  minimumSize: const Size(44, 44),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  disabledForegroundColor: cs.onSurfaceVariant
                                      .withValues(alpha: 0.36),
                                  disabledBackgroundColor: cs
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.65),
                                ),
                                icon: isActionBusy
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        isEditing
                                            ? Icons.check_rounded
                                            : Icons.send_rounded,
                                        size: 22,
                                      ),
                                tooltip: isActionBusy
                                    ? (isEditing ? 'Saving…' : 'Adding…')
                                    : (isEditing
                                        ? 'Save edits'
                                        : 'Add sentence'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksBullet extends StatelessWidget {
  const _HowItWorksBullet({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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

class _ListeningPreviewSheet extends StatefulWidget {
  const _ListeningPreviewSheet({
    required this.theme,
    required this.asset,
  });

  final ThemeData theme;
  final StoryAudioAsset asset;

  @override
  State<_ListeningPreviewSheet> createState() => _ListeningPreviewSheetState();
}

class _ListeningPreviewSheetState extends State<_ListeningPreviewSheet> {
  late final AudioPlayer _player;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final a = widget.asset;
      final url = (a.sourceUrl ?? '').trim();
      final path = (a.localPath ?? '').trim();

      if (a.hasUploadedSourceUrl && url.isNotEmpty) {
        await _player.setUrl(url);
      } else if (path.isNotEmpty) {
        await _player.setFilePath(path);
      } else {
        if (!mounted) return;
        setState(
            () => _error = 'Preview isn’t available for this attachment yet.');
        return;
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this audio for preview.');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final cs = theme.colorScheme;
    final name = (widget.asset.displayName ?? '').trim();
    final fileName = (widget.asset.localFileName ?? '').trim();

    final title = name.isNotEmpty
        ? name
        : (fileName.isNotEmpty ? fileName : 'Audio attachment');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Listening preview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            )
          else if (!_ready)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading audio…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing == true;
                return FilledButton.icon(
                  onPressed: () async {
                    if (playing) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                  },
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(playing ? 'Pause' : 'Play'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              },
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _QuizTestPlaySheet extends StatefulWidget {
  const _QuizTestPlaySheet({
    required this.theme,
    required this.tabTitle,
    required this.items,
    required this.scrollController,
  });

  final ThemeData theme;
  final String tabTitle;
  final List<QuizEntry> items;
  final ScrollController scrollController;

  @override
  State<_QuizTestPlaySheet> createState() => _QuizTestPlaySheetState();
}

class _QuizTestPlaySheetState extends State<_QuizTestPlaySheet> {
  late final PageController _pages;
  int _pageIndex = 0;
  final Map<String, int> _selectedById = {};
  final Set<String> _revealed = {};

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final cs = theme.colorScheme;
    final items = widget.items;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final mq = MediaQuery.sizeOf(context);
    final pageH = math.max(220.0, math.min(320.0, mq.height * 0.34));

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomPad + 8),
      children: [
        Text(
          'Test-play: ${widget.tabTitle}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          items.isEmpty
              ? 'No quiz items in this tab yet.'
              : '${_pageIndex + 1} of ${items.length}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Add at least one ${widget.tabTitle.toLowerCase()} quiz item, then test-play it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          )
        else
          SizedBox(
            height: pageH,
            child: PageView.builder(
              controller: _pages,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, index) {
                final q = items[index];
                final selected = _selectedById[q.id];
                final revealed = _revealed.contains(q.id);
                final correct = q.correctIndex;
                final exSource = (q.explanations?.my ?? '').trim();
                final exEn = (q.explanations?.en ?? '').trim();

                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: ListView(
                      children: [
                        Text(
                          q.prompt,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < 4; i++) ...[
                          _QuizOptionRow(
                            theme: theme,
                            label: String.fromCharCode(65 + i),
                            text: q.options[i],
                            selected: selected == i,
                            state: revealed
                                ? (i == correct
                                    ? _QuizOptionState.correct
                                    : (selected == i
                                        ? _QuizOptionState.wrong
                                        : _QuizOptionState.neutral))
                                : _QuizOptionState.neutral,
                            onTap: () => setState(() {
                              _selectedById[q.id] = i;
                            }),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: selected == null
                                  ? null
                                  : () => setState(() => _revealed.add(q.id)),
                              child: const Text('Reveal answer'),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _revealed.remove(q.id)),
                              child: const Text('Hide'),
                            ),
                          ],
                        ),
                        if (revealed) ...[
                          const SizedBox(height: 10),
                          if (exSource.isNotEmpty) ...[
                            Text(
                              'Explanation (source)',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              exSource,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (exEn.isNotEmpty) ...[
                            if (exSource.isNotEmpty) const SizedBox(height: 10),
                            Text(
                              'English (optional)',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              exEn,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (exSource.isEmpty && exEn.isEmpty)
                            Text(
                              'No explanation for this item.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: items.isEmpty || _pageIndex <= 0
                    ? null
                    : () => _pages.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prev'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: items.isEmpty || _pageIndex >= items.length - 1
                    ? null
                    : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _QuizOptionState { neutral, correct, wrong }

class _QuizOptionRow extends StatelessWidget {
  const _QuizOptionRow({
    required this.theme,
    required this.label,
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final ThemeData theme;
  final String label;
  final String text;
  final bool selected;
  final _QuizOptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;

    Color? bg;
    Color fg = cs.onSurface;
    Color border = cs.outlineVariant;

    if (state == _QuizOptionState.correct) {
      bg = cs.primaryContainer.withValues(alpha: 0.55);
      fg = cs.onPrimaryContainer;
      border = cs.primary.withValues(alpha: 0.45);
    } else if (state == _QuizOptionState.wrong) {
      bg = cs.errorContainer.withValues(alpha: 0.55);
      fg = cs.onErrorContainer;
      border = cs.error.withValues(alpha: 0.45);
    } else if (selected) {
      bg = cs.surfaceContainerHighest.withValues(alpha: 0.55);
      fg = cs.onSurface;
      border = cs.primary.withValues(alpha: 0.25);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg ?? cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
