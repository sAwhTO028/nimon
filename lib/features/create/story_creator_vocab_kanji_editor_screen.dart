import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_navigation_debug.dart';
import 'package:nimon/features/create/creator_reorder_handle.dart';
import 'package:nimon/features/create/creator_drawer_publish.dart';
import 'package:nimon/features/create/creator_drawer_publish_labels.dart';
import 'package:nimon/features/create/creator_learn_mode_sync.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_furigana_tokens.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/widgets/creator_fit_info_bottom_sheet.dart';
import 'package:nimon/features/create/widgets/creator_info_bottom_sheet.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/ui/reading/nimon_furigana_preview_style.dart';
import 'package:nimon/ui/reading/nimon_japanese_sentence_line.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/features/learn/learn_creator_module_tokens.dart';

/// Keeps the Story sentences host on the embedded Vocabulary panel after local edits
/// (no navigation; no-op when not on that host).
///
/// [debugAction] is logged in debug mode only ([kDebugMode]); remove or empty when
/// diagnostics are no longer needed.
void _retainEmbeddedVocabularyPanel(
  WidgetRef ref,
  String debugAction, {
  BuildContext? routerContext,
}) {
  if (routerContext != null) {
    try {
      final st = GoRouterState.of(routerContext);
      creatorNavDebug(
        'retain_embed',
        'invoke action=$debugAction | uri=${st.uri} | matchedLocation=${st.matchedLocation} | '
            'panel=${st.uri.queryParameters['panel']}',
      );
    } catch (_) {
      creatorNavDebug(
          'retain_embed', 'invoke action=$debugAction | (no GoRouterState)');
    }
  }
  ref
      .read(creatorDrawerSessionProvider.notifier)
      .retainSentencesHostEmbeddedStep(
        CreatorWorkspaceStep.vocabulary,
        debugAction: debugAction,
      );
}

/// Manual V1 editor for the Vocabulary / Kanji Learn module (one story draft).
class StoryCreatorVocabKanjiEditorScreen extends ConsumerWidget {
  const StoryCreatorVocabKanjiEditorScreen({super.key});

  static String _normalizeSelectedTerm(String raw) {
    final t = raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String _normTermForComparison(String raw) =>
      _normalizeSelectedTerm(raw);

  /// V1: max length for a phrase picked as one vocab item.
  static const int _maxVocabPickLength = 48;

  static bool _selectionHasLexicalContent(String t) {
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFFa-zA-Z0-9]')
        .hasMatch(t);
  }

  static bool _isValidVocabPick(String? normalized) {
    if (normalized == null || normalized.isEmpty) return false;
    if (normalized.length > _maxVocabPickLength) return false;
    if (!_selectionHasLexicalContent(normalized)) return false;
    return true;
  }

  /// Matches sentence-card “support” line semantics for gloss availability.
  static String glossStatusLine(VocabularyKanjiEntry e) {
    final g = e.glosses;
    if (g == null) return 'No meanings yet';
    final hasEn = g.en != null && g.en!.trim().isNotEmpty;
    final hasSource = g.my != null && g.my!.trim().isNotEmpty;
    if (hasEn && hasSource) return 'Source + English';
    if (hasEn) return 'English';
    if (hasSource) return 'Source';
    return 'No meanings yet';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handleCreatorBack() {
      unawaited(handleCreatorBackPressed(context, ref));
    }

    final draft = ref.watch(storyCreatorDraftDataProvider);
    final session = ref.watch(creatorDrawerSessionProvider);
    final progress = buildCreatorDrawerProgressModel(draft: draft);
    final publishModel = buildStoryReviewDisplayModel(draft);
    final draftState = ref.watch(storyCreatorDraftProvider);
    final roSig = draftState.readOnlyPublishedCoreSig;
    final roBaseline = draftState.publishedEditReadOnlyBaselineSig;
    final flBaseline = draftState.publishedEditFullLearnBaselineSig;
    final roExists = computeReadOnlyPublishedExists(
      draft: draft,
      readOnlyPublishedCoreSig: roSig,
    );
    final roDirty = computeReadOnlyHasUnpublishedChanges(
      draft: draft,
      readOnlyPublishedCoreSig: roSig,
      dirty: draftState.dirty,
      publishedEditReadOnlyBaselineSig: roBaseline,
    );
    final flExists = draft.publishState == StoryPublishState.fullLearnPublished;
    final flDirty = computeFullLearnHasUnpublishedChanges(
      draft: draft,
      readOnlyPublishedCoreSig: roSig,
      dirty: draftState.dirty,
      publishedEditReadOnlyBaselineSig: roBaseline,
      publishedEditFullLearnBaselineSig: flBaseline,
    );

    return CreatorRouteSyncListener(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          handleCreatorBack();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Vocabulary / Kanji'),
            leading: NimonBackButton(
              onPressed: handleCreatorBack,
            ),
            actions: [
              IconButton(
                tooltip: 'Review created vocabulary',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () =>
                    StoryCreatorVocabKanjiEditorScreen._showVocabReview(
                  context,
                  ref,
                ),
              ),
              IconButton(
                tooltip: 'How to add vocabulary / kanji',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () =>
                    StoryCreatorVocabKanjiEditorScreen._showVocabHowTo(context),
              ),
              Builder(
                builder: (ctx) {
                  return IconButton(
                    tooltip: 'Creator progress',
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  );
                },
              ),
            ],
          ),
          endDrawer: CreatorProgressDrawer(
            drawerKeySlot: kCreatorProgressDrawerKeyVocabulary,
            coreItems: progress.coreItems,
            learnItems: progress.learnItems,
            publishModel: publishModel,
            creatorDraft: draft,
            localDraftDirty: draftState.dirty,
            readOnlyPublishedCoreSig: roSig,
            publishedEditReadOnlyBaselineSig: roBaseline,
            publishedEditFullLearnBaselineSig: flBaseline,
            readOnlyPublishedExists: roExists,
            readOnlyHasUnpublishedChanges: roDirty,
            fullLearnPublishedExists: flExists,
            fullLearnHasUnpublishedChanges: flDirty,
            learnModeEnabled: session.learnModeEnabled,
            currentStepId: creatorEffectiveActiveStep(session),
            onLearnModeChanged: (v) {
              applyCreatorLearnMode(
                context: context,
                ref: ref,
                learnModeEnabled: v,
                closeDrawerOnTurnOff: () => Navigator.of(context).maybePop(),
              );
            },
            onOpenStep: (route) {
              Navigator.of(context).maybePop(); // close drawer if open
              final id = ref.read(storyCreatorDraftDataProvider).id;
              context.push(createStoryProgressRouteWithDraftId(route, id));
            },
            onSaveDraft: () async {
              Navigator.of(context).maybePop();
              await ref
                  .read(storyCreatorDraftProvider.notifier)
                  .globalSaveDraftNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All changes saved locally.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onPublish: (mode) async {
              Navigator.of(context).maybePop();
              await performCreatorDrawerPublish(
                ref: ref,
                context: context,
                mode: mode,
              );
            },
          ),
          body: StoryCreatorVocabKanjiModuleBody(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            showBottomActions: true,
            showLearnExitButton: true,
            useCompactModuleHeader: false,
            onExit: handleCreatorBack,
          ),
        ),
      ),
    );
  }

  static Future<bool?> _confirmDelete(BuildContext context, String term) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Remove “$term” from this story’s vocabulary list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static Future<String?> _showPickFromStorySheet(
    BuildContext context, {
    required String storyText,
    required Set<String> existingTerms,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final sheetH = (mq.size.height * 0.88).clamp(360.0, 720.0);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SizedBox(
            height: sheetH,
            child: _PickVocabularyFromStorySheet(
              storyText: storyText,
              existingTerms: existingTerms,
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showVocabTermEditSheet(
    BuildContext context, {
    required VocabularyKanjiEntry existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VocabTermEditBottomSheet(existing: existing),
    );
  }

  static Future<void> _showVocabDetailsSheet(
    BuildContext context, {
    required VocabularyKanjiEntry existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VocabDetailsBottomSheet(existing: existing),
    );
  }

  static void _showVocabHowTo(BuildContext context) {
    showCreatorFitInfoBottomSheet(
      context: context,
      title: 'How to add vocabulary / kanji',
      children: const [
        CreatorInfoBulletColumn(
          lines: [
            'Tap Add entry.',
            'Select a word or phrase from the story.',
            'Choose Vocabulary or Kanji.',
            'Add source meaning first.',
            'Optionally add English meaning.',
            'Optionally add up to 3 example sentences.',
          ],
        ),
      ],
    );
  }

  static void _showVocabReview(BuildContext context, WidgetRef ref) {
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.termJapanese,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
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
          ),
        );
      },
    );
  }
}

class _VocabTermEditBottomSheet extends ConsumerStatefulWidget {
  const _VocabTermEditBottomSheet({required this.existing});

  final VocabularyKanjiEntry existing;

  @override
  ConsumerState<_VocabTermEditBottomSheet> createState() =>
      _VocabTermEditBottomSheetState();
}

class _VocabTermEditBottomSheetState
    extends ConsumerState<_VocabTermEditBottomSheet> {
  late final TextEditingController _termCtrl;
  late final TextEditingController _readingCtrl;
  late VocabularyKanjiEntryType _type;
  String? _error;

  void _popSheet() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void initState() {
    super.initState();
    _termCtrl = TextEditingController(text: widget.existing.termJapanese);
    _readingCtrl = TextEditingController(text: widget.existing.reading ?? '');
    _type = widget.existing.type;
    _termCtrl.addListener(_onTermChanged);
  }

  void _onTermChanged() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  void dispose() {
    _termCtrl.removeListener(_onTermChanged);
    _termCtrl.dispose();
    _readingCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final term = _termCtrl.text.trim();
    if (term.isEmpty) {
      setState(() => _error = 'Vocabulary text cannot be empty.');
      return;
    }
    ref.read(storyCreatorDraftProvider.notifier).updateVocabKanjiEntry(
          entryId: widget.existing.id,
          type: _type,
          termJapanese: term,
          readingRaw: _readingCtrl.text,
          meanings: widget.existing.glosses,
          examplePairs: widget.existing.examplePairs,
        );
    _retainEmbeddedVocabularyPanel(ref, 'vocab_edit_save',
        routerContext: context);
    _popSheet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final fill = cs.surface;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit vocabulary',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update the headword, reading, and whether this item is treated as '
              'vocabulary or kanji in Learn.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _termCtrl,
              decoration: InputDecoration(
                labelText: 'Vocabulary text',
                hintText: '例：図書館 / 静か / 環境',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                errorText: _error,
                filled: true,
                fillColor: fill,
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _readingCtrl,
              decoration: InputDecoration(
                labelText: 'Reading / furigana (optional)',
                hintText: '例：としょかん / しずか / かんきょう',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
                fillColor: fill,
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 18),
            Text(
              'Type',
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<VocabularyKanjiEntryType>(
              segments: const [
                ButtonSegment(
                  value: VocabularyKanjiEntryType.vocabulary,
                  label: Text('Vocabulary'),
                ),
                ButtonSegment(
                  value: VocabularyKanjiEntryType.kanji,
                  label: Text('Kanji'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _popSheet,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalizedPairDraft {
  _LocalizedPairDraft({
    String source = '',
    String english = '',
    bool englishExpanded = false,
  })  : sourceCtrl = TextEditingController(text: source),
        englishCtrl = TextEditingController(text: english),
        englishExpanded = englishExpanded;

  final TextEditingController sourceCtrl;
  final TextEditingController englishCtrl;
  bool englishExpanded;

  bool get hasEnglish => englishCtrl.text.trim().isNotEmpty;
  bool get hasSource => sourceCtrl.text.trim().isNotEmpty;
  bool get isEmpty => !hasSource && !hasEnglish;
  bool get isEnglishOnly => !hasSource && hasEnglish;

  void dispose() {
    sourceCtrl.dispose();
    englishCtrl.dispose();
  }
}

class _VocabDetailsDraft {
  _VocabDetailsDraft({
    required this.meaning,
    required this.examples,
  });

  final _LocalizedPairDraft meaning;
  final List<_LocalizedPairDraft> examples;

  void dispose() {
    meaning.dispose();
    for (final e in examples) {
      e.dispose();
    }
  }
}

/// Japanese example line: matches draft story furigana when the text aligns; otherwise plain.
Widget _vocabExampleJapanesePreview({
  required TextEditingController sourceCtrl,
  required List<StorySentenceItem> storySentences,
  required ThemeData theme,
  required ColorScheme colorScheme,
}) {
  return ListenableBuilder(
    listenable: sourceCtrl,
    builder: (context, _) {
      final raw = sourceCtrl.text;
      if (raw.trim().isEmpty) return const SizedBox.shrink();

      final match =
          storySentenceMatchingTrimmedExampleLine(raw, storySentences);
      final displayText = match?.japaneseText ?? raw;
      final spans = match?.furiganaSpans ?? <FuriganaSpan>[];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: NimonJapaneseSentenceLine(
              text: displayText,
              spans: spans,
              theme: theme,
              previewContext: NimonFuriganaPreviewContext.details,
            ),
          ),
        ),
      );
    },
  );
}

class _VocabDetailsTermHeader extends StatelessWidget {
  const _VocabDetailsTermHeader({
    required this.entry,
    required this.theme,
    required this.colorScheme,
  });

  final VocabularyKanjiEntry entry;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final reading = entry.reading?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.termJapanese,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.type.displayLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (reading != null && reading.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reading,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VocabDetailsBottomSheet extends ConsumerStatefulWidget {
  const _VocabDetailsBottomSheet({required this.existing});

  final VocabularyKanjiEntry existing;

  @override
  ConsumerState<_VocabDetailsBottomSheet> createState() =>
      _VocabDetailsBottomSheetState();
}

class _VocabDetailsBottomSheetState
    extends ConsumerState<_VocabDetailsBottomSheet> {
  late final _VocabDetailsDraft _draft;
  bool _sourceMeaningEnglishExpanded = false;

  String? _saveError;

  void _maybeAutoExpandMeaningEnglish() {
    final hasEn = _draft.meaning.englishCtrl.text.trim().isNotEmpty;
    if (hasEn && !_sourceMeaningEnglishExpanded) {
      setState(() => _sourceMeaningEnglishExpanded = true);
    }
  }

  @override
  void initState() {
    super.initState();
    final meaningSource = widget.existing.glosses?.my ?? '';
    final meaningEn = widget.existing.glosses?.en ?? '';

    final examples = <_LocalizedPairDraft>[];
    for (final p in widget.existing.effectiveExamplePairs) {
      final src = p.sourceExample;
      final en = p.englishExample;
      examples.add(
        _LocalizedPairDraft(
          source: src,
          english: en,
          englishExpanded: en.trim().isNotEmpty,
        ),
      );
    }

    _draft = _VocabDetailsDraft(
      meaning: _LocalizedPairDraft(
        source: meaningSource,
        english: meaningEn,
        englishExpanded: meaningEn.trim().isNotEmpty,
      ),
      examples: examples,
    );

    _sourceMeaningEnglishExpanded = _draft.meaning.hasEnglish;
    _draft.meaning.englishCtrl.addListener(_maybeAutoExpandMeaningEnglish);
  }

  @override
  void dispose() {
    _draft.meaning.englishCtrl.removeListener(_maybeAutoExpandMeaningEnglish);
    _draft.dispose();
    super.dispose();
  }

  void _removeBlockAt(int index) {
    if (index < 0 || index >= _draft.examples.length) return;
    setState(() {
      _draft.examples[index].dispose();
      _draft.examples.removeAt(index);
    });
  }

  void _addBlock() {
    if (_draft.examples.length >= 3) return;
    setState(() {
      _draft.examples.add(_LocalizedPairDraft());
    });
  }

  void _save(BuildContext sheetContext) {
    setState(() => _saveError = null);

    // Validate: English example cannot stand alone without source example.
    for (var i = 0; i < _draft.examples.length; i++) {
      final ex = _draft.examples[i];
      final src = ex.sourceCtrl.text.trim();
      final en = ex.englishCtrl.text.trim();
      if (src.isEmpty && en.isNotEmpty) {
        setState(() {
          _saveError =
              'Example ${i + 1} has an English line but no source sentence.';
          ex.englishExpanded = true;
        });
        return;
      }
    }

    final n = ref.read(storyCreatorDraftProvider.notifier);
    final gloss = LocalizedMeanings.layerFromEnMy(
      enRaw: _draft.meaning.englishCtrl.text,
      myRaw: _draft.meaning.sourceCtrl.text,
      preserveExtrasFrom: widget.existing.glosses,
    );

    // Persist only valid / non-empty example blocks.
    final pairs = <VocabularyExamplePair>[];
    for (final b in _draft.examples) {
      final src = b.sourceCtrl.text.trim();
      final en = b.englishCtrl.text.trim();
      if (src.isEmpty && en.isEmpty) continue;
      if (src.isEmpty && en.isNotEmpty)
        continue; // (guard; should have returned)
      pairs.add(
        VocabularyExamplePair(
          sourceExample: b.sourceCtrl.text,
          englishExample: b.englishCtrl.text,
        ),
      );
    }
    n.updateVocabKanjiEntry(
      entryId: widget.existing.id,
      type: widget.existing.type,
      termJapanese: widget.existing.termJapanese,
      readingRaw: widget.existing.reading ?? '',
      meanings: gloss,
      examplePairs: pairs,
    );
    _retainEmbeddedVocabularyPanel(ref, 'vocab_details_save',
        routerContext: sheetContext);
    Navigator.of(sheetContext, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final fill = cs.surface;
    final englishFill = cs.surfaceContainerLowest;

    Widget sectionTitle(String title) => Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: 0.15,
          ),
        );

    Widget helperText(String text) => Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        );

    Widget accordionRow({
      required bool expanded,
      required String collapsedLabel,
      required String expandedLabel,
      required VoidCallback onTap,
      bool secondary = false,
    }) {
      final labelStyle = secondary
          ? theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.25,
            )
          : theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.15,
            );
      return Material(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less_rounded : Icons.add_rounded,
                  size: 20,
                  color: cs.primary.withValues(alpha: secondary ? 0.75 : 0.9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expanded ? expandedLabel : collapsedLabel,
                    style: labelStyle,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text(
              'Entry details',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            helperText(
              'Term at top; then meanings; then up to three example sentences.',
            ),
            const SizedBox(height: 18),
            _VocabDetailsTermHeader(
              entry: widget.existing,
              theme: theme,
              colorScheme: cs,
            ),
            const SizedBox(height: 22),
            sectionTitle('Meanings'),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListenableBuilder(
                      listenable: _draft.meaning.sourceCtrl,
                      builder: (context, _) {
                        if (_draft.meaning.sourceCtrl.text.trim().isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No source meaning yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.72),
                              height: 1.35,
                            ),
                          ),
                        );
                      },
                    ),
                    TextField(
                      controller: _draft.meaning.sourceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Source meaning',
                        hintText: 'Add a gloss in your source language',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: fill,
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    accordionRow(
                      expanded: _sourceMeaningEnglishExpanded,
                      collapsedLabel: 'English meaning (optional)',
                      expandedLabel: 'English meaning (optional)',
                      secondary: true,
                      onTap: () => setState(() {
                        _sourceMeaningEnglishExpanded =
                            !_sourceMeaningEnglishExpanded;
                      }),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 180),
                      crossFadeState: _sourceMeaningEnglishExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: _draft.meaning.englishCtrl,
                          decoration: InputDecoration(
                            labelText: 'English meaning',
                            hintText: 'Optional translation or gloss',
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: englishFill,
                            labelStyle: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          minLines: 2,
                          maxLines: 5,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            sectionTitle('Example sentences'),
            const SizedBox(height: 6),
            helperText(
              'Up to three blocks. Japanese uses the same line rendering as Storytelling.',
            ),
            const SizedBox(height: 10),
            if (_draft.examples.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'No example sentences yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _draft.examples.length >= 3 ? null : _addBlock,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add example'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final e in _draft.examples.asMap().entries) ...[
              _PairedExampleBlockCard(
                index: e.key,
                fields: e.value,
                theme: theme,
                colorScheme: cs,
                storySentences:
                    ref.watch(storyCreatorDraftDataProvider).sentences,
                englishExpanded: e.value.englishExpanded,
                onToggleEnglish: () => setState(() {
                  e.value.englishExpanded = !e.value.englishExpanded;
                }),
                onRemove: () => _removeBlockAt(e.key),
              ),
              if (e.key < _draft.examples.length - 1) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.22),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 16),
              Text(
                _saveError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _save(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairedExampleBlockCard extends StatelessWidget {
  const _PairedExampleBlockCard({
    required this.index,
    required this.fields,
    required this.theme,
    required this.colorScheme,
    required this.storySentences,
    required this.englishExpanded,
    required this.onToggleEnglish,
    this.onRemove,
  });

  final int index;
  final _LocalizedPairDraft fields;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final List<StorySentenceItem> storySentences;
  final bool englishExpanded;
  final VoidCallback onToggleEnglish;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasEnglish = fields.englishCtrl.text.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Example ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove example',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Japanese',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            _vocabExampleJapanesePreview(
              sourceCtrl: fields.sourceCtrl,
              storySentences: storySentences,
              theme: theme,
              colorScheme: colorScheme,
            ),
            TextField(
              controller: fields.sourceCtrl,
              decoration: InputDecoration(
                labelText: 'Edit source sentence',
                hintText: 'Enter or paste the Japanese sentence',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
                fillColor: colorScheme.surface,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Material(
              color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggleEnglish,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Icon(
                        englishExpanded
                            ? Icons.expand_less_rounded
                            : Icons.add_rounded,
                        size: 20,
                        color: colorScheme.primary.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          englishExpanded
                              ? 'English (optional)'
                              : (hasEnglish
                                  ? 'English (optional)'
                                  : 'Add English line (optional)'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                      Icon(
                        englishExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: englishExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: fields.englishCtrl,
                  decoration: InputDecoration(
                    labelText: 'English',
                    hintText: 'Optional translation or gloss',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.92),
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared module UI used by both:
/// - `/create/story/learn/vocabulary` route screen
/// - drawer-based creator workspace panel
class StoryCreatorVocabKanjiModuleBody extends ConsumerWidget {
  const StoryCreatorVocabKanjiModuleBody({
    super.key,
    required this.padding,
    required this.showBottomActions,
    this.showLearnExitButton = true,
    this.useCompactModuleHeader = false,
    this.hideWorkspaceModuleTitle = false,
    this.onExit,
  });

  final EdgeInsets padding;
  final bool showBottomActions;
  final bool showLearnExitButton;
  final bool useCompactModuleHeader;

  /// When true, omits the large module title so the sentences host pinned header is the only title.
  final bool hideWorkspaceModuleTitle;
  final VoidCallback? onExit;

  /// Story text shown in the pick-from-story sheet (draft sentences, reading order).
  static String _pickerStoryPlaintext(CreatorStoryV1 draft) {
    final t = draft.sentencesPlaintextDisplay.trim();
    if (t.isNotEmpty) return draft.sentencesPlaintextDisplay;
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final items = draft.vocabularyKanji.entries;

    final headerPadding =
        EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0);
    final listHorizontal =
        EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useCompactModuleHeader) ...[
                if (!hideWorkspaceModuleTitle) ...[
                  Text(
                    'Vocabulary / Kanji',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  'Pick terms from your story, then refine details.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ] else ...[
                Text(
                  'Manual vocab & kanji items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add key terms readers should learn from this story. Meanings can be English and/or Myanmar. '
                  'At least one valid entry completes this module.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final existingTerms = <String>{
                        for (final e in draft.vocabularyKanji.entries)
                          StoryCreatorVocabKanjiEditorScreen
                              ._normTermForComparison(
                            e.termJapanese,
                          ),
                      };
                      final selected = await StoryCreatorVocabKanjiEditorScreen
                          ._showPickFromStorySheet(
                        context,
                        storyText: _pickerStoryPlaintext(draft),
                        existingTerms: existingTerms,
                      );
                      if (selected == null || selected.trim().isEmpty) return;
                      final reading = readingForVocabSelectionFromDraft(
                        sentences: draft.sentences,
                        selectedTerm: selected,
                      );
                      n.addVocabKanjiEntry(
                        type: VocabularyKanjiEntryType.vocabulary,
                        termJapanese: selected,
                        readingRaw: reading ?? '',
                        meanings: null,
                        examplePairs: const [],
                      );
                      _retainEmbeddedVocabularyPanel(
                        ref,
                        'vocab_add_from_story',
                        routerContext: context,
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: listHorizontal +
                      const EdgeInsets.only(top: 12, bottom: 16),
                  child: _EmptyState(theme: theme),
                )
              : ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    listHorizontal.left,
                    12,
                    listHorizontal.right,
                    16 + bottomInset,
                  ),
                  buildDefaultDragHandles: false,
                  dragStartBehavior: DragStartBehavior.down,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final t = Curves.easeOut.transform(animation.value);
                        return Material(
                          color: Colors.transparent,
                          elevation: lerpDouble(0, 8, t) ?? 0,
                          shadowColor: Colors.black.withValues(alpha: 0.18 * t),
                          borderRadius: BorderRadius.circular(14),
                          child: child,
                        );
                      },
                    );
                  },
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    n.reorderVocabKanjiEntries(oldIndex, newIndex);
                    _retainEmbeddedVocabularyPanel(ref, 'vocab_reorder',
                        routerContext: context);
                  },
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Padding(
                      key: ValueKey(e.id),
                      padding: EdgeInsets.only(
                          bottom: i < items.length - 1 ? 10 : 0),
                      child: _VocabKanjiEntryCard(
                        index: i,
                        entry: e,
                        theme: theme,
                        onMoreOpened: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onMoreCanceled: () {},
                        onDelete: () async {
                          final ok = await StoryCreatorVocabKanjiEditorScreen
                              ._confirmDelete(
                            context,
                            e.termJapanese,
                          );
                          if (ok != true) return;
                          n.deleteVocabKanjiEntry(e.id);
                          _retainEmbeddedVocabularyPanel(
                            ref,
                            'vocab_delete',
                            routerContext: context,
                          );
                        },
                        onEditTerm: () => StoryCreatorVocabKanjiEditorScreen
                            ._showVocabTermEditSheet(
                          context,
                          existing: e,
                        ),
                        onDetails: () => StoryCreatorVocabKanjiEditorScreen
                            ._showVocabDetailsSheet(
                          context,
                          existing: e,
                        ),
                        reorderDragStartListener: ReorderableDragStartListener(
                          index: i,
                          child: CreatorReorderHandle(
                            theme: theme,
                            semanticsLabel: 'Drag to reorder vocabulary item',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (showBottomActions)
          Material(
            elevation: 8,
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLearnExitButton) ...[
                    FilledButton(
                      onPressed: onExit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back to story'),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );

    if (useCompactModuleHeader) {
      return Material(
        color: theme.colorScheme.surface,
        child: column,
      );
    }
    return column;
  }
}

/// Modal bottom sheet body: pick Japanese from story sentences as a new vocab term.
class _PickVocabularyFromStorySheet extends StatefulWidget {
  const _PickVocabularyFromStorySheet({
    required this.storyText,
    required this.existingTerms,
  });

  final String storyText;
  final Set<String> existingTerms;

  @override
  State<_PickVocabularyFromStorySheet> createState() =>
      _PickVocabularyFromStorySheetState();
}

class _PickVocabularyFromStorySheetState
    extends State<_PickVocabularyFromStorySheet> {
  late final String _displayText;
  late final bool _hasStory;

  String? _picked;

  @override
  void initState() {
    super.initState();
    final lines = widget.storyText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _hasStory = lines.isNotEmpty;
    _displayText = lines.join('\n\n');
  }

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? _) {
    final full = _displayText;
    if (full.isEmpty || !selection.isValid || selection.isCollapsed) {
      setState(() => _picked = null);
      return;
    }
    final start = selection.start.clamp(0, full.length);
    final end = selection.end.clamp(0, full.length);
    if (end <= start) {
      setState(() => _picked = null);
      return;
    }
    final raw = full.substring(start, end);
    final norm = StoryCreatorVocabKanjiEditorScreen._normalizeSelectedTerm(raw);
    setState(() => _picked = norm.isEmpty ? null : norm);
  }

  bool get _duplicate {
    final p = _picked;
    if (p == null || p.isEmpty) return false;
    return widget.existingTerms
        .contains(StoryCreatorVocabKanjiEditorScreen._normTermForComparison(p));
  }

  bool get _canAdd =>
      StoryCreatorVocabKanjiEditorScreen._isValidVocabPick(_picked) &&
      !_duplicate;

  Color _statusColor(NimonColorTokens tc, ColorScheme cs) {
    if (!_hasStory) return tc.textSecondary;
    if (_picked == null || _picked!.isEmpty) {
      return tc.textSecondary;
    }
    if (_duplicate) return cs.error;
    if (!StoryCreatorVocabKanjiEditorScreen._isValidVocabPick(_picked)) {
      return cs.error;
    }
    return tc.textPrimary;
  }

  String _statusText() {
    if (!_hasStory) {
      return 'Add sentences in Story Sentences first, then return here.';
    }
    if (_picked == null || _picked!.isEmpty) {
      return 'No selection yet.';
    }
    if (_duplicate) return 'Already added.';
    if (_picked!.length >
        StoryCreatorVocabKanjiEditorScreen._maxVocabPickLength) {
      return 'Selection is too long (max '
          '${StoryCreatorVocabKanjiEditorScreen._maxVocabPickLength} characters).';
    }
    if (!StoryCreatorVocabKanjiEditorScreen._selectionHasLexicalContent(
        _picked!)) {
      return 'Selection is only punctuation or symbols.';
    }
    return 'Selected: ${_picked!}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tc = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select vocabulary from story',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasStory
                          ? 'Select a word or phrase from the story, then tap Add.'
                          : 'Add sentences first, then pick a term here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tc.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                style: IconButton.styleFrom(foregroundColor: tc.textPrimary),
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop<void>(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _hasStory
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: tc.appBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tc.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: SelectableText(
                          key: const ValueKey('pick_story_text'),
                          _displayText,
                          onSelectionChanged: _onSelectionChanged,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: tc.textPrimary,
                            height: 1.65,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: tc.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tc.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Text(
                        'No story sentences yet.\n'
                        'Add sentences first, then come back here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: tc.textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tc.appBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tc.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _statusText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _statusColor(tc, cs),
                        height: 1.35,
                        fontWeight: _canAdd ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_picked != null && _picked!.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: tc.textPrimary,
                      ),
                      onPressed: () => setState(() => _picked = null),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: tc.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                height: 1,
                thickness: 1,
                color: tc.border,
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    TextButton(
                      style:
                          TextButton.styleFrom(foregroundColor: tc.textPrimary),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true)
                              .pop<void>(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _canAdd
                          ? () => Navigator.of(context, rootNavigator: true)
                              .pop<String>(_picked)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: tc.actionPrimary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        disabledBackgroundColor:
                            tc.disabled.withValues(alpha: 0.35),
                        disabledForegroundColor: tc.textSecondary,
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Text(
          'No items yet. Tap “Add entry” to add a vocabulary word or a kanji.\n'
          'Tip: meanings can be English and/or Myanmar — both are optional.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: tc.textSecondary,
          ),
        ),
      ),
    );
  }
}

enum _VocabMoreAction { delete }

class _VocabKanjiEntryCard extends StatelessWidget {
  const _VocabKanjiEntryCard({
    required this.index,
    required this.entry,
    required this.theme,
    required this.onMoreOpened,
    required this.onMoreCanceled,
    required this.onDelete,
    required this.onEditTerm,
    required this.onDetails,
    required this.reorderDragStartListener,
  });

  final int index;
  final VocabularyKanjiEntry entry;
  final ThemeData theme;
  final VoidCallback onMoreOpened;
  final VoidCallback onMoreCanceled;
  final VoidCallback onDelete;
  final VoidCallback onEditTerm;
  final VoidCallback onDetails;
  final Widget reorderDragStartListener;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final reading = entry.reading?.trim();
    final status = StoryCreatorVocabKanjiEditorScreen.glossStatusLine(entry);
    final cardBg = learnCreatorModuleCardSurfaceColor(context);
    final cardBorder = learnCreatorModuleCardBorderColor(context);
    final ink = learnCreatorModulePrimaryTextColor(context);
    final muted = learnCreatorModuleSecondaryTextColor(context);
    final actionFg = learnCreatorModuleActionForegroundColor(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder.withValues(alpha: 0.7)),
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
                    color: muted,
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.termJapanese,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
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
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  entry.type.displayLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<_VocabMoreAction>(
                        tooltip: 'More',
                        padding: EdgeInsets.zero,
                        offset: const Offset(0, 4),
                        onOpened: onMoreOpened,
                        onCanceled: onMoreCanceled,
                        onSelected: (a) {
                          if (a == _VocabMoreAction.delete) onDelete();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: _VocabMoreAction.delete,
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
                  if (reading != null && reading.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reading,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted.withValues(alpha: 0.82),
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
                              onPressed: onDetails,
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                              ),
                              label: const Text('Details'),
                              style: TextButton.styleFrom(
                                foregroundColor: actionFg,
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: onEditTerm,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                foregroundColor: actionFg,
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
