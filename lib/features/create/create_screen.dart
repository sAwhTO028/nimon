import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/create/create_story_basics_form.dart';
import 'package:nimon/features/create/data/media_upload_repository_provider.dart';
import 'package:nimon/features/create/story_basics_cover_upload_outcome.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/core/media/media_upload_error_mapper.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';

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

  Future<StoryBasicsCoverUploadOutcome> _uploadCoverFromGallery(
      XFile file) async {
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.uploadMedia,
    )) {
      return StoryBasicsCoverUploadOutcome.pendingLocal(inlineHint: null);
    }
    final tok = await ref.read(authTokenStoreProvider).readTokens();
    if (tok == null || tok.accessToken.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validationMessageKeyLocalized(
                context,
                'protected.uploadMedia.login',
              ),
            ),
          ),
        );
      }
      return StoryBasicsCoverUploadOutcome.pendingLocal(inlineHint: null);
    }
    try {
      final r = await ref.read(mediaUploadRepositoryProvider).uploadCover(file);
      return StoryBasicsCoverUploadOutcome.ok(r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mediaUploadUserMessageLocalized(
                context,
                e,
                surface: MediaUploadSurface.storyCover,
              ),
            ),
          ),
        );
      }
      return StoryBasicsCoverUploadOutcome.pendingLocal(
        inlineHint:
            mounted ? coverUploadFailureInlineHintLocalized(context, e) : null,
      );
    }
  }

  Future<void> _handleCreate() async {
    if (!await ensureProtectedActionAllowed(
      context,
      action: ProtectedActionType.createStory,
    )) {
      return;
    }
    final payload = _formKey.currentState?.buildPayloadIfValid();
    if (payload == null) return;
    final nav = context;
    // Add/Create is ONLY for starting a brand-new story draft.
    // Start an ephemeral draft session; the first persist happens when fields are applied.
    ref.read(storyCreatorDraftProvider.notifier).reset();
    try {
      await ref
          .read(storyCreatorDraftProvider.notifier)
          .applyBasicsAndWaitPersist(
            title: payload.title,
            category: payload.category,
            level: payload.level,
            description: payload.description,
            promptSourceNote: payload.promptSourceNote,
            targetDurationBandKey: payload.targetDurationBandKey,
            coverImageUrl: payload.coverImageUrl,
          );
    } on AppQuotaExceededException catch (e) {
      if (!nav.mounted) return;
      await showQuotaExceededDialog(nav, e);
      return;
    }
    if (!nav.mounted) return;
    final created = ref.read(storyCreatorDraftDataProvider);
    nav.push('/create/story/sentences?draftId=${created.id}');
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
    final coverUploadAllowed =
        ref.watch(authSessionProvider) is AuthSessionAuthenticated;
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
                onCoverUpload: _uploadCoverFromGallery,
                coverUploadAllowed: coverUploadAllowed,
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
                    onPressed: canSubmit
                        ? () => unawaited(_handleSaveFromReview())
                        : null,
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

    final tc = theme.colors;
    return Scaffold(
      backgroundColor: tc.appBackground,
      appBar: AppBar(
        backgroundColor: tc.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: NimonBackButton(
          onPressed: () => unawaited(handleCreatorBackPressed(context, ref)),
          icon: Icons.close_rounded,
          tooltip: 'Close',
        ),
        title: Text(
          'Create',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
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
                  onPressed:
                      canSubmit ? () => unawaited(_handleCreate()) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canSubmit
                        ? tc.actionPrimary
                        : tc.disabled.withValues(alpha: 0.35),
                    foregroundColor: canSubmit
                        ? theme.colorScheme.onPrimary
                        : tc.textSecondary,
                    disabledBackgroundColor:
                        tc.disabled.withValues(alpha: 0.35),
                    disabledForegroundColor: tc.textSecondary,
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
              onCoverUpload: _uploadCoverFromGallery,
              coverUploadAllowed: coverUploadAllowed,
            ),
          ),
        ],
      ),
    );
  }
}
