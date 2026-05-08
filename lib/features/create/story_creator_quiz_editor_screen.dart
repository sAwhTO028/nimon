import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_publish.dart';
import 'package:nimon/features/create/creator_drawer_publish_labels.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_learn_mode_sync.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_quiz_ui_state.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/creator_reorder_handle.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

export 'package:nimon/features/create/creator_quiz_ui_state.dart'
    show quizTabIndexProvider;

/// Quiz editor tabs: Semantics (vocab + kanji), Grammar, Sentence.
const int kQuizEditorTabCount = 3;

const List<CreatorQuizCategory> kSemanticsNewItemCategories =
    <CreatorQuizCategory>[
  CreatorQuizCategory.vocabulary,
  CreatorQuizCategory.kanji,
];

/// Clamps the quiz editor tab index to the current 3-tab model (0..2).
///
/// Legacy persisted index `3` (old Sentence) is folded into `2`.
int clampQuizEditorTabIndex(int index) {
  if (index == 3) return 2;
  return index.clamp(0, kQuizEditorTabCount - 1);
}

String quizEditorTabLabel(int tabIndex) {
  switch (tabIndex.clamp(0, kQuizEditorTabCount - 1)) {
    case 0:
      return 'Semantics';
    case 1:
      return 'Grammar';
    case 2:
      return 'Sentence';
    default:
      return 'Semantics';
  }
}

bool quizEntryMatchesEditorTab(QuizEntry q, int tabIndex) {
  switch (tabIndex.clamp(0, kQuizEditorTabCount - 1)) {
    case 0:
      return q.category == CreatorQuizCategory.vocabulary ||
          q.category == CreatorQuizCategory.kanji;
    case 1:
      return q.category == CreatorQuizCategory.grammar;
    case 2:
      return q.category == CreatorQuizCategory.sampleSentence;
    default:
      return false;
  }
}

CreatorQuizCategory defaultCategoryForQuizEditorTab(int tabIndex) {
  switch (tabIndex.clamp(0, kQuizEditorTabCount - 1)) {
    case 0:
      return CreatorQuizCategory.vocabulary;
    case 1:
      return CreatorQuizCategory.grammar;
    case 2:
      return CreatorQuizCategory.sampleSentence;
    default:
      return CreatorQuizCategory.vocabulary;
  }
}

/// Manual V1 editor for the Quiz Learn module (MCQ items) attached to the current draft.
class StoryCreatorQuizEditorScreen extends ConsumerWidget {
  const StoryCreatorQuizEditorScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handleCreatorBack() =>
        unawaited(handleCreatorBackPressed(context, ref));

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
            title: const Text('Quiz Practice'),
            leading: NimonBackButton(
              onPressed: handleCreatorBack,
            ),
            actions: [
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
            drawerKeySlot: kCreatorProgressDrawerKeyQuiz,
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
          body: StoryCreatorQuizModuleBody(
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

  static Future<bool?> _confirmDelete(BuildContext context, String prompt) {
    final p = prompt.trim();
    final label = p.isEmpty
        ? 'this quiz item'
        : '“${p.substring(0, p.length.clamp(0, 60))}”';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quiz item?'),
        content: Text('Remove $label from this story’s quiz list?'),
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
    QuizEntry? existing,
    CreatorQuizCategory? defaultCategory,
    bool lockCategoryToDefault = false,
    List<CreatorQuizCategory>? newItemCategoryChoices,
  }) async {
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final theme = Theme.of(context);

    final defaultCat = defaultCategory ?? CreatorQuizCategory.vocabulary;
    var category = existing?.category ?? defaultCat;
    final promptCtrl = TextEditingController(text: existing?.prompt ?? '');
    final aCtrl =
        TextEditingController(text: existing?.options.elementAtOrNull(0) ?? '');
    final bCtrl =
        TextEditingController(text: existing?.options.elementAtOrNull(1) ?? '');
    final cCtrl =
        TextEditingController(text: existing?.options.elementAtOrNull(2) ?? '');
    final dCtrl =
        TextEditingController(text: existing?.options.elementAtOrNull(3) ?? '');
    var correctIndex = existing?.correctIndex ?? 0;
    final exSourceCtrl =
        TextEditingController(text: existing?.explanations?.my ?? '');
    final exEnCtrl =
        TextEditingController(text: existing?.explanations?.en ?? '');
    var englishExpanded = (existing?.explanations?.en ?? '').trim().isNotEmpty;

    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F3EA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            void save() {
              final prompt = promptCtrl.text.trim();
              final opts = [
                aCtrl.text.trim(),
                bCtrl.text.trim(),
                cCtrl.text.trim(),
                dCtrl.text.trim(),
              ];
              if (prompt.isEmpty) {
                setSheetState(() => error = 'Prompt / question is required.');
                return;
              }
              if (opts.any((o) => o.isEmpty)) {
                setSheetState(
                    () => error = 'All 4 answer options are required.');
                return;
              }
              if (correctIndex < 0 || correctIndex > 3) {
                setSheetState(() => error = 'Choose the correct answer.');
                return;
              }

              final explanations = LocalizedMeanings.layerFromEnMy(
                enRaw: exEnCtrl.text,
                myRaw: exSourceCtrl.text,
                preserveExtrasFrom: existing?.explanations,
              );

              if (existing == null) {
                n.addQuizEntry(
                  category: category,
                  prompt: prompt,
                  options4: opts,
                  correctIndex: correctIndex,
                  explanations: explanations,
                  sourceNoteRaw: '',
                );
              } else {
                n.updateQuizEntry(
                  entryId: existing.id,
                  category: category,
                  prompt: prompt,
                  options4: opts,
                  correctIndex: correctIndex,
                  explanations: explanations,
                  // Keep legacy value if it exists; we don’t expose it in the V1 sheet anymore.
                  sourceNoteRaw: existing.sourceNote ?? '',
                );
              }
              Navigator.pop(ctx2);
            }

            Widget optField(String label, TextEditingController c) {
              return TextField(
                controller: c,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                minLines: 1,
                maxLines: 2,
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'Add quiz item' : 'Edit quiz item',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'V1 MCQ: category + prompt + 4 options + 1 correct answer.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (existing == null &&
                        newItemCategoryChoices != null &&
                        newItemCategoryChoices.isNotEmpty) ...[
                      DropdownMenu<CreatorQuizCategory>(
                        initialSelection:
                            newItemCategoryChoices.contains(category)
                                ? category
                                : newItemCategoryChoices.first,
                        expandedInsets: EdgeInsets.zero,
                        label: const Text('Category'),
                        onSelected: (v) {
                          if (v == null) return;
                          setSheetState(() => category = v);
                        },
                        dropdownMenuEntries: [
                          for (final c in newItemCategoryChoices)
                            DropdownMenuEntry(
                              value: c,
                              label: c.displayLabel,
                            ),
                        ],
                      ),
                    ] else if (existing == null && lockCategoryToDefault) ...[
                      Row(
                        children: [
                          Text(
                            'Category',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x0A000000),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              defaultCat.displayLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      DropdownMenu<CreatorQuizCategory>(
                        initialSelection: category,
                        expandedInsets: EdgeInsets.zero,
                        label: const Text('Category'),
                        onSelected: (v) {
                          if (v == null) return;
                          setSheetState(() => category = v);
                        },
                        dropdownMenuEntries: [
                          for (final c in CreatorQuizCategory.values)
                            DropdownMenuEntry(
                              value: c,
                              label: c.displayLabel,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: promptCtrl,
                      decoration: InputDecoration(
                        labelText: 'Prompt / question',
                        border: const OutlineInputBorder(),
                        errorText: error,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Answer options',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    optField('Option A', aCtrl),
                    const SizedBox(height: 10),
                    optField('Option B', bCtrl),
                    const SizedBox(height: 10),
                    optField('Option C', cCtrl),
                    const SizedBox(height: 10),
                    optField('Option D', dCtrl),
                    const SizedBox(height: 14),
                    Text(
                      'Correct answer',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 4; i++)
                          ChoiceChip(
                            label: Text(String.fromCharCode(65 + i)),
                            selected: correctIndex == i,
                            onSelected: (_) {
                              setSheetState(() => correctIndex = i);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Explanation (optional)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: exSourceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (source language)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setSheetState(
                          () => englishExpanded = !englishExpanded,
                        ),
                        icon: Icon(
                          englishExpanded
                              ? Icons.expand_less_rounded
                              : Icons.add_rounded,
                          size: 18,
                        ),
                        label: const Text('Add English explanation (optional)'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 180),
                      crossFadeState: englishExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(height: 2),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextField(
                          controller: exEnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'English explanation (optional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          minLines: 2,
                          maxLines: 5,
                          onChanged: (v) {
                            if (!englishExpanded && v.trim().isNotEmpty) {
                              setSheetState(() => englishExpanded = true);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: save,
                      child: Text(
                          existing == null ? 'Add quiz item' : 'Save changes'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Dispose controllers after the sheet route fully tears down. Disposing
    // immediately after await can race with teardown animations and cause
    // "used after being disposed" (especially in widget tests).
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        promptCtrl.dispose();
        aCtrl.dispose();
        bCtrl.dispose();
        cCtrl.dispose();
        dCtrl.dispose();
        exSourceCtrl.dispose();
        exEnCtrl.dispose();
      }),
    );
  }
}

/// Shared Quiz module UI used by:
/// - `/create/story/learn/quiz` route screen
/// - embedded creator workspace panel (Story sentences host)
class StoryCreatorQuizModuleBody extends ConsumerWidget {
  const StoryCreatorQuizModuleBody({
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
    return _QuizModuleBodyInner(
      padding: padding,
      showBottomActions: showBottomActions,
      showLearnExitButton: showLearnExitButton,
      useCompactModuleHeader: useCompactModuleHeader,
      hideWorkspaceModuleTitle: hideWorkspaceModuleTitle,
      onExit: onExit,
    );
  }
}

class _QuizModuleBodyInner extends ConsumerStatefulWidget {
  const _QuizModuleBodyInner({
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
  final bool hideWorkspaceModuleTitle;
  final VoidCallback? onExit;

  @override
  ConsumerState<_QuizModuleBodyInner> createState() =>
      _QuizModuleBodyInnerState();
}

class _QuizModuleBodyInnerState extends ConsumerState<_QuizModuleBodyInner>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(quizTabIndexProvider);
    final initial = clampQuizEditorTabIndex(stored);
    if (initial != stored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(quizTabIndexProvider.notifier).state = initial;
        }
      });
    }
    _tabs = TabController(
      length: kQuizEditorTabCount,
      vsync: this,
      initialIndex: initial,
    );
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      ref.read(quizTabIndexProvider.notifier).state = _tabs.index;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final tabIndex = _tabs.index;
    final selectedCategory = defaultCategoryForQuizEditorTab(tabIndex);
    final allItems = draft.quiz.entries;
    final items = [
      for (final q in allItems)
        if (quizEntryMatchesEditorTab(q, tabIndex)) q,
    ];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        widget.padding.left,
        widget.padding.top,
        widget.padding.right,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.hideWorkspaceModuleTitle) ...[
            Text(
              widget.useCompactModuleHeader
                  ? 'Quiz'
                  : 'Manual quiz items (MCQ)',
              style: theme.textTheme.titleLarge?.copyWith(
                color: StoryCreatorQuizEditorScreen._ink,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Add practice questions for readers of this story. Each item has one category, 4 options, and one correct answer. '
            'Explanations (English/Myanmar) are optional.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: StoryCreatorQuizEditorScreen._muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: StoryCreatorQuizEditorScreen._ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => StoryCreatorQuizEditorScreen._showUpsertSheet(
                  context,
                  ref,
                  defaultCategory: selectedCategory,
                  lockCategoryToDefault: tabIndex != 0,
                  newItemCategoryChoices:
                      tabIndex == 0 ? kSemanticsNewItemCategories : null,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add quiz'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabs,
              isScrollable: false,
              labelColor: cs.onSurface,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              tabs: const [
                Tab(text: 'Semantics'),
                Tab(text: 'Grammar'),
                Tab(text: 'Sentence'),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );

    Widget body;
    if (items.isEmpty) {
      body = ListView(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          0,
          widget.padding.right,
          widget.showBottomActions ? 16 + bottomInset : widget.padding.bottom,
        ),
        children: [
          const SizedBox(height: 2),
          _EmptyState(theme: theme),
        ],
      );
    } else {
      body = ReorderableListView.builder(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          0,
          widget.padding.right,
          widget.showBottomActions ? 16 + bottomInset : widget.padding.bottom,
        ),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          if (tabIndex == 0) {
            n.reorderQuizEntryWithinCategories(
              categories: const {
                CreatorQuizCategory.vocabulary,
                CreatorQuizCategory.kanji,
              },
              oldIndexInCategory: oldIndex,
              newIndexInCategory: newIndex,
            );
          } else {
            n.reorderQuizEntryWithinCategory(
              category: selectedCategory,
              oldIndexInCategory: oldIndex,
              newIndexInCategory: newIndex,
            );
          }
        },
        itemBuilder: (context, i) {
          final q = items[i];
          return Padding(
            key: ValueKey(q.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuizCard(
              entry: q,
              reorderDragStartListener: ReorderableDragStartListener(
                index: i,
                child: CreatorReorderHandle(
                  theme: theme,
                  semanticsLabel: 'Drag to reorder quiz item',
                ),
              ),
              onEdit: () => StoryCreatorQuizEditorScreen._showUpsertSheet(
                context,
                ref,
                existing: q,
              ),
              onDelete: () async {
                final ok = await StoryCreatorQuizEditorScreen._confirmDelete(
                    context, q.prompt);
                if (ok != true) return;
                n.deleteQuizEntry(q.id);
              },
            ),
          );
        },
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );

    if (!widget.showBottomActions) return content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
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
                if (widget.showLearnExitButton) ...[
                  FilledButton(
                    onPressed: widget.onExit,
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
          'No quiz items yet. Tap “Add quiz” to create a multiple-choice question.\n'
          'Tip: you can add an optional explanation in English and/or Myanmar.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: const Color(0xFF5C5A55),
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.entry,
    required this.reorderDragStartListener,
    required this.onEdit,
    required this.onDelete,
  });

  final QuizEntry entry;
  final Widget reorderDragStartListener;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final prompt = entry.prompt.trim();
    final correctLabel = String.fromCharCode(65 + entry.correctIndex);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.category.displayLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Correct: $correctLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                      ),
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: cs.error,
                              ),
                              const SizedBox(width: 10),
                              const Text('Delete item'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  prompt.isEmpty ? '—' : prompt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: reorderDragStartListener,
          ),
        ],
      ),
    );
  }
}

extension on List<String> {
  String? elementAtOrNull(int i) => (i >= 0 && i < length) ? this[i] : null;
}
