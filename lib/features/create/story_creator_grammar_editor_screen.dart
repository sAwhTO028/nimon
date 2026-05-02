import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_drawer_publish.dart';
import 'package:nimon/features/create/creator_learn_mode_sync.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_reorder_handle.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_grammar_overlays.dart';
import 'package:nimon/features/create/creator_read_only_publish_tracking.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// One editable grammar example row inside the add/edit sheet (max 3 rows).
class _GrammarSheetExampleRow {
  _GrammarSheetExampleRow({
    required this.jp,
    required this.sourceMeaning,
    required this.enMeaning,
    this.expandEn = false,
  });

  factory _GrammarSheetExampleRow.fromData(GrammarExample e) {
    final m = e.meanings;
    final enTxt = m?.en?.trim() ?? '';
    return _GrammarSheetExampleRow(
      jp: TextEditingController(text: e.japanese),
      sourceMeaning: TextEditingController(text: m?.my ?? ''),
      enMeaning: TextEditingController(text: m?.en ?? ''),
      expandEn: enTxt.isNotEmpty,
    );
  }

  factory _GrammarSheetExampleRow.empty() {
    return _GrammarSheetExampleRow(
      jp: TextEditingController(),
      sourceMeaning: TextEditingController(),
      enMeaning: TextEditingController(),
    );
  }

  final TextEditingController jp;
  final TextEditingController sourceMeaning;
  final TextEditingController enMeaning;
  bool expandEn;

  void dispose() {
    jp.dispose();
    sourceMeaning.dispose();
    enMeaning.dispose();
  }

  GrammarExample toExample(
    int index,
    List<GrammarExample>? existingExamples,
  ) {
    final preserve = (existingExamples != null &&
            index >= 0 &&
            index < existingExamples.length)
        ? existingExamples[index].meanings
        : null;
    final m = LocalizedMeanings.layerFromEnMy(
      enRaw: enMeaning.text,
      myRaw: sourceMeaning.text,
      preserveExtrasFrom: preserve,
    );
    return GrammarExample(japanese: jp.text.trim(), meanings: m);
  }
}

class _GrammarUpsertResult {
  const _GrammarUpsertResult({
    required this.headline,
    required this.formRaw,
    required this.meanings,
    required this.usage,
    required this.examples,
    required this.mistakeWrongRaw,
    required this.mistakeCorrectRaw,
    required this.relatedNote,
  });

  final String headline;
  final String formRaw;
  final LocalizedMeanings? meanings;
  final LocalizedMeanings? usage;
  final List<GrammarExample> examples;
  final String mistakeWrongRaw;
  final String mistakeCorrectRaw;
  final LocalizedMeanings? relatedNote;
}

class _GrammarPatternSheet extends StatefulWidget {
  const _GrammarPatternSheet({
    required this.theme,
    required this.existing,
  });

  final ThemeData theme;
  final GrammarEntry? existing;

  @override
  State<_GrammarPatternSheet> createState() => _GrammarPatternSheetState();
}

class _GrammarPatternSheetState extends State<_GrammarPatternSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _formCtrl;

  late final TextEditingController _meaningSourceCtrl;
  late final TextEditingController _meaningEnCtrl;

  late final TextEditingController _usageSourceCtrl;
  late final TextEditingController _usageEnCtrl;

  late final TextEditingController _wrongCtrl;
  late final TextEditingController _correctCtrl;

  late final TextEditingController _noteSourceCtrl;
  late final TextEditingController _noteEnCtrl;

  late final List<_GrammarSheetExampleRow> _exampleRows;

  late bool _expandMeaningEn;
  late bool _expandUsageEn;
  late bool _expandNoteEn;

  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _titleCtrl = TextEditingController(text: existing?.headline ?? '');
    _formCtrl = TextEditingController(text: existing?.form ?? '');

    _meaningSourceCtrl = TextEditingController(text: existing?.meanings?.my ?? '');
    _meaningEnCtrl = TextEditingController(text: existing?.meanings?.en ?? '');

    _usageSourceCtrl = TextEditingController(text: existing?.usage?.my ?? '');
    _usageEnCtrl = TextEditingController(text: existing?.usage?.en ?? '');

    _wrongCtrl = TextEditingController(text: existing?.mistakeWrong ?? '');
    _correctCtrl = TextEditingController(text: existing?.mistakeCorrect ?? '');

    _noteSourceCtrl = TextEditingController(text: existing?.relatedNote?.my ?? '');
    _noteEnCtrl = TextEditingController(text: existing?.relatedNote?.en ?? '');

    _exampleRows = <_GrammarSheetExampleRow>[
      if (existing?.examples.isNotEmpty ?? false)
        for (final ex in existing!.examples.take(3)) _GrammarSheetExampleRow.fromData(ex),
    ];

    _expandMeaningEn = (existing?.meanings?.en?.trim().isNotEmpty ?? false);
    _expandUsageEn = (existing?.usage?.en?.trim().isNotEmpty ?? false);
    _expandNoteEn = (existing?.relatedNote?.en?.trim().isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _formCtrl.dispose();
    _meaningSourceCtrl.dispose();
    _meaningEnCtrl.dispose();
    _usageSourceCtrl.dispose();
    _usageEnCtrl.dispose();
    _wrongCtrl.dispose();
    _correctCtrl.dispose();
    _noteSourceCtrl.dispose();
    _noteEnCtrl.dispose();
    for (final r in _exampleRows) {
      r.dispose();
    }
    super.dispose();
  }

  List<GrammarExample> _buildExamplesFromRows() {
    final existingList = widget.existing?.examples;
    final built = <GrammarExample>[
      for (var i = 0; i < _exampleRows.length; i++) _exampleRows[i].toExample(i, existingList),
    ];
    return built.where((e) => !e.isEmptyV1).toList();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Pattern title is required.');
      return;
    }
    final existing = widget.existing;
    final meanings = LocalizedMeanings.layerFromEnMy(
      enRaw: _meaningEnCtrl.text,
      myRaw: _meaningSourceCtrl.text,
      preserveExtrasFrom: existing?.meanings,
    );
    final usage = LocalizedMeanings.layerFromEnMy(
      enRaw: _usageEnCtrl.text,
      myRaw: _usageSourceCtrl.text,
      preserveExtrasFrom: existing?.usage,
    );
    final note = LocalizedMeanings.layerFromEnMy(
      enRaw: _noteEnCtrl.text,
      myRaw: _noteSourceCtrl.text,
      preserveExtrasFrom: existing?.relatedNote,
    );
    final examples = _buildExamplesFromRows();

    Navigator.pop<_GrammarUpsertResult?>(
      context,
      _GrammarUpsertResult(
        headline: title,
        formRaw: _formCtrl.text,
        meanings: meanings,
        usage: usage,
        examples: examples,
        mistakeWrongRaw: _wrongCtrl.text,
        mistakeCorrectRaw: _correctCtrl.text,
        relatedNote: note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final existing = widget.existing;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final cs = theme.colorScheme;

    Widget commonEnglishAccordion({
      required String closedLabel,
      required TextEditingController controller,
      required bool expanded,
      required VoidCallback onToggle,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerLowest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Icon(
                      expanded ? Icons.expand_less_rounded : Icons.add_rounded,
                      size: 20,
                      color: cs.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        closedLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                              color: StoryCreatorGrammarEditorScreen._ink,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ) ??
                            const TextStyle(),
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
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Common English',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
                fillColor: cs.surface,
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'Add pattern' : 'Edit pattern',
              style: theme.textTheme.titleLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pattern title is required. Everything else is optional in V1.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoryCreatorGrammarEditorScreen._muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Pattern title',
                hintText: '例：〜について',
                border: const OutlineInputBorder(),
                errorText: _error,
                filled: true,
                fillColor: cs.surface,
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _formCtrl,
              decoration: InputDecoration(
                labelText: 'Form (optional)',
                hintText: '例：N + について',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: cs.surface,
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 16),
            Text(
              'Meaning (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _meaningSourceCtrl,
              decoration: const InputDecoration(
                labelText: 'Source meaning',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            commonEnglishAccordion(
              closedLabel: 'Add Common English meaning (optional)',
              controller: _meaningEnCtrl,
              expanded: _expandMeaningEn,
              onToggle: () => setState(() => _expandMeaningEn = !_expandMeaningEn),
            ),
            const SizedBox(height: 16),
            Text(
              'Usage / when to use (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usageSourceCtrl,
              decoration: const InputDecoration(
                labelText: 'Source usage',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            commonEnglishAccordion(
              closedLabel: 'Add Common English usage (optional)',
              controller: _usageEnCtrl,
              expanded: _expandUsageEn,
              onToggle: () => setState(() => _expandUsageEn = !_expandUsageEn),
            ),
            const SizedBox(height: 18),
            Text(
              'Examples (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Up to 3 examples. Add rows as needed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoryCreatorGrammarEditorScreen._muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in _exampleRows.asMap().entries) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Example ${entry.key + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: StoryCreatorGrammarEditorScreen._ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Remove example',
                            onPressed: () {
                              final removeIndex = entry.key;
                              setState(() {
                                final r = _exampleRows.removeAt(removeIndex);
                                r.dispose();
                              });
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: entry.value.jp,
                        decoration: const InputDecoration(
                          labelText: 'Source example sentence',
                          hintText: 'Usually Japanese from your story',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          filled: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: entry.value.sourceMeaning,
                        decoration: const InputDecoration(
                          labelText: 'Source example meaning',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          filled: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      commonEnglishAccordion(
                        closedLabel: 'Add Common English example meaning (optional)',
                        controller: entry.value.enMeaning,
                        expanded: entry.value.expandEn,
                        onToggle: () => setState(
                          () => entry.value.expandEn = !entry.value.expandEn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_exampleRows.length < 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_exampleRows.length < 3) {
                        _exampleRows.add(_GrammarSheetExampleRow.empty());
                      }
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add example'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Common mistake (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Source language only in V1 (no separate Common English pair).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoryCreatorGrammarEditorScreen._muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _wrongCtrl,
              decoration: const InputDecoration(
                labelText: 'Wrong form (source)',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _correctCtrl,
              decoration: const InputDecoration(
                labelText: 'Correct form (source)',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Related note (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: StoryCreatorGrammarEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteSourceCtrl,
              decoration: const InputDecoration(
                labelText: 'Source note',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            commonEnglishAccordion(
              closedLabel: 'Add Common English note (optional)',
              controller: _noteEnCtrl,
              expanded: _expandNoteEn,
              onToggle: () => setState(() => _expandNoteEn = !_expandNoteEn),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              child: Text(existing == null ? 'Add pattern' : 'Save changes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop<_GrammarUpsertResult?>(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual V1 editor for the Grammar Learn module (one story draft).
class StoryCreatorGrammarEditorScreen extends ConsumerWidget {
  const StoryCreatorGrammarEditorScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

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
    final roExists =
        roSig != null || draft.publishState != StoryPublishState.draft;
    final roDirty = roSig != null &&
        computeReadOnlyPublishedCoreSignature(draft) != roSig;
    final flExists =
        draft.publishState == StoryPublishState.fullLearnPublished;
    final flDirty = draftState.dirty;

    return CreatorRouteSyncListener(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          handleCreatorBack();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Grammar Learn'),
            leading: NimonBackButton(
              onPressed: handleCreatorBack,
            ),
            actions: [
              IconButton(
                tooltip: 'Test-play grammar',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () =>
                    StoryCreatorGrammarOverlays.showTestPlay(context, ref),
              ),
              IconButton(
                tooltip: 'How to add grammar patterns',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () => StoryCreatorGrammarOverlays.showHowTo(context),
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
            drawerKeySlot: kCreatorProgressDrawerKeyGrammar,
            coreItems: progress.coreItems,
            learnItems: progress.learnItems,
            publishModel: publishModel,
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
              Navigator.of(context).maybePop();
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
          body: StoryCreatorGrammarModuleBody(
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

  static Future<bool?> _confirmDelete(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete grammar pattern?'),
        content: Text('Remove “$title” from this story’s grammar list?'),
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

  static Future<void> _showUpsertSheet(
    BuildContext context,
    WidgetRef ref, {
    GrammarEntry? existing,
  }) async {
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final theme = Theme.of(context);

    final result = await showModalBottomSheet<_GrammarUpsertResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F3EA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GrammarPatternSheet(theme: theme, existing: existing),
    );

    if (!context.mounted) return;
    if (result == null) return;

    if (existing == null) {
      n.addGrammarEntry(
        headline: result.headline,
        formRaw: result.formRaw,
        meanings: result.meanings,
        usage: result.usage,
        examples: result.examples,
        mistakeWrongRaw: result.mistakeWrongRaw,
        mistakeCorrectRaw: result.mistakeCorrectRaw,
        relatedNote: result.relatedNote,
      );
    } else {
      n.updateGrammarEntry(
        entryId: existing.id,
        headline: result.headline,
        formRaw: result.formRaw,
        meanings: result.meanings,
        usage: result.usage,
        examples: result.examples,
        mistakeWrongRaw: result.mistakeWrongRaw,
        mistakeCorrectRaw: result.mistakeCorrectRaw,
        relatedNote: result.relatedNote,
      );
    }
  }
}

/// Shared Grammar module UI used by:
/// - `/create/story/learn/grammar` route screen
/// - embedded creator workspace panel (Story sentences host)
class StoryCreatorGrammarModuleBody extends ConsumerWidget {
  const StoryCreatorGrammarModuleBody({
    super.key,
    required this.padding,
    required this.showBottomActions,
    required this.showLearnExitButton,
    required this.useCompactModuleHeader,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final items = draft.grammar.entries;

    final headerTextStyle = theme.textTheme.titleLarge?.copyWith(
      color: StoryCreatorGrammarEditorScreen._ink,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    final headerPadding =
        EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0);
    final listHorizontal =
        EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0);
    final listBottomPad =
        showBottomActions ? 16 + bottomInset : padding.bottom;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideWorkspaceModuleTitle) ...[
          Text(
            useCompactModuleHeader ? 'Grammar' : 'Manual grammar patterns',
            style: headerTextStyle,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Add grammar patterns readers should learn from this story. '
          'Use source language as the main text; Common English is optional. '
          'At least one valid pattern completes this module.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: StoryCreatorGrammarEditorScreen._muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${items.length} ${items.length == 1 ? 'pattern' : 'patterns'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: StoryCreatorGrammarEditorScreen._ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => StoryCreatorGrammarEditorScreen._showUpsertSheet(
                context,
                ref,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add pattern'),
            ),
          ],
        ),
      ],
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headerPadding,
          child: header,
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
                    listBottomPad,
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
                          shadowColor:
                              Colors.black.withValues(alpha: 0.18 * t),
                          borderRadius: BorderRadius.circular(14),
                          child: child,
                        );
                      },
                    );
                  },
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    n.reorderGrammarEntries(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Padding(
                      key: ValueKey(e.id),
                      padding: EdgeInsets.only(
                        bottom: i < items.length - 1 ? 10 : 0,
                      ),
                      child: _GrammarCard(
                        entry: e,
                        theme: theme,
                        onMoreOpened: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onMoreCanceled: () {},
                        onEdit: () => StoryCreatorGrammarEditorScreen._showUpsertSheet(
                              context,
                              ref,
                              existing: e,
                            ),
                        onDelete: () async {
                          final ok =
                              await StoryCreatorGrammarEditorScreen._confirmDelete(
                            context,
                            e.headline,
                          );
                          if (ok != true) return;
                          n.deleteGrammarEntry(e.id);
                        },
                        reorderDragStartListener: ReorderableDragStartListener(
                          index: i,
                          child: CreatorReorderHandle(
                            theme: theme,
                            semanticsLabel: 'Drag to reorder grammar pattern',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (!showBottomActions) return list;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
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

class _GrammarReviewListCard extends StatelessWidget {
  const _GrammarReviewListCard({
    required this.entry,
    required this.theme,
    required this.colorScheme,
    required this.meaningSummary,
  });

  final GrammarEntry entry;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? meaningSummary;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final form = entry.form?.trim();
    return Card(
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
              entry.headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (meaningSummary != null) ...[
              const SizedBox(height: 6),
              Text(
                meaningSummary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
            if (form != null && form.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                form,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Text(
          'No grammar patterns yet. Tap “Add pattern” to add one.\n'
          'Tip: source meaning is primary; Common English is optional.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: const Color(0xFF5C5A55),
          ),
        ),
      ),
    );
  }
}

enum _GrammarMoreAction { delete }

class _GrammarCard extends StatelessWidget {
  const _GrammarCard({
    required this.entry,
    required this.theme,
    required this.onMoreOpened,
    required this.onMoreCanceled,
    required this.onEdit,
    required this.onDelete,
    required this.reorderDragStartListener,
  });

  final GrammarEntry entry;
  final ThemeData theme;
  final VoidCallback onMoreOpened;
  final VoidCallback onMoreCanceled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget reorderDragStartListener;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  String? _meaningSummary() {
    final m = entry.meanings;
    if (m == null) return null;
    final source = m.my?.trim();
    final en = m.en?.trim();
    if (source != null && source.isNotEmpty) return source;
    if (en != null && en.isNotEmpty) return en;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final meaning = _meaningSummary();
    final form = entry.form?.trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      entry.headline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_GrammarMoreAction>(
                  tooltip: 'More',
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 4),
                  onOpened: onMoreOpened,
                  onCanceled: onMoreCanceled,
                  onSelected: (a) {
                    if (a == _GrammarMoreAction.delete) onDelete();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: _GrammarMoreAction.delete,
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
                          color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (meaning != null && meaning.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                meaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
            if (form != null && form.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                form,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
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
    );
  }
}

