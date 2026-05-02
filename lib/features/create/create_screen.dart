import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/create_story_basics_form.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Create entry from the dock **+ Add**. Step 1 is the unified Story basics form.
///
/// [editFromReview] opens the same form prefilled from the shared draft; saving returns to Review.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({
    super.key,
    this.initialTab,
    this.editFromReview = false,
  });

  final String? initialTab;
  final bool editFromReview;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  // Use separate keys for the two mutually-exclusive modes.
  // This avoids accidental GlobalKey reuse if both subtrees ever overlap during
  // route transitions/animations.
  final _createFormKey = GlobalKey<CreateStoryBasicsFormState>(
    debugLabel: 'CreateScreen_create_form',
  );
  final _editFromReviewFormKey = GlobalKey<CreateStoryBasicsFormState>(
    debugLabel: 'CreateScreen_edit_from_review_form',
  );

  GlobalKey<CreateStoryBasicsFormState> get _formKey =>
      widget.editFromReview ? _editFromReviewFormKey : _createFormKey;

  Future<void> _handleCreate() async {
    final payload = _formKey.currentState?.buildPayloadIfValid();
    if (payload == null) return;
    // Add/Create is ONLY for starting a brand-new story draft.
    // Start an ephemeral draft session; the first persist happens when fields are applied.
    ref.read(storyCreatorDraftProvider.notifier).reset();
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
    final created = ref.read(storyCreatorDraftDataProvider);
    context.push('/create/story/sentences?draftId=${created.id}');
  }

  Future<void> _handleSaveFromReview() async {
    final payload = _formKey.currentState?.buildPayloadIfValid();
    if (payload == null) return;
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
    await handleCreatorBackPressed(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(storyCreatorDraftDataProvider);
    final canSubmit = _formKey.currentState?.isStep1Complete ?? false;

    if (widget.editFromReview) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: theme.colorScheme.surface,
          leading: NimonBackButton(
            onPressed: () => unawaited(handleCreatorBackPressed(context, ref)),
          ),
          title: Text(
            'Story basics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CreateStoryBasicsForm(
                key: _formKey,
                initialDraft: draft,
                progressSheetActionLabel: 'Save changes',
                onFieldsChanged: () => setState(() {}),
              ),
            ),
            Material(
              elevation: 8,
              shadowColor: Colors.black26,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton(
                    onPressed: canSubmit ? () => unawaited(_handleSaveFromReview()) : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save changes'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: NimonBackButton(
          onPressed: () => unawaited(handleCreatorBackPressed(context, ref)),
          icon: Icons.close_rounded,
          tooltip: 'Close',
        ),
        title: const Text(
          'Create',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: canSubmit ? () => unawaited(_handleCreate()) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        canSubmit ? Colors.blue : Colors.grey.shade300,
                    foregroundColor:
                        canSubmit ? Colors.white : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'CREATE',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CreateStoryBasicsForm(
              key: _formKey,
              initialDraft: null,
              progressSheetActionLabel: 'CREATE',
              onFieldsChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
