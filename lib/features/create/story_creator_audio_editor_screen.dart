import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/creator_audio_upload_sheet.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_drawer_publish.dart';
import 'package:nimon/features/create/creator_drawer_publish_labels.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/creator_learn_mode_sync.dart';
import 'package:nimon/features/create/creator_progress_drawer.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/data/media_upload_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_review_display.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 creator editor for one story-level audio asset (public **http(s) URL** first for remote sync).
class StoryCreatorAudioEditorScreen extends ConsumerWidget {
  const StoryCreatorAudioEditorScreen({super.key});

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
            title: const Text('Listening / Audio'),
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
            drawerKeySlot: kCreatorProgressDrawerKeyListening,
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
          body: StoryCreatorListeningModuleBody(
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

  static Future<bool?> _confirmRemove(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove audio?'),
        content: const Text('Remove the story-level audio from this draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showUpsertSheet(
    BuildContext context,
    WidgetRef ref, {
    StoryAudioAsset? existing,
  }) async {
    final n = ref.read(storyCreatorDraftProvider.notifier);
    final initialUrl = (existing != null && existing.hasUploadedSourceUrl)
        ? (existing.sourceUrl ?? '').trim()
        : '';
    final tok = await ref.read(authTokenStoreProvider).readTokens();
    if (!context.mounted) return;
    final canUpload = tok != null && tok.accessToken.trim().isNotEmpty;

    final result = await showModalBottomSheet<AudioUpsertResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F3EA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Future<MediaUploadResponse?> uploadAudio(PlatformFile file) async {
          final t = await ref.read(authTokenStoreProvider).readTokens();
          if (t == null || t.accessToken.trim().isEmpty) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Sign in to upload media.')),
              );
            }
            return null;
          }
          try {
            return await ref
                .read(mediaUploadRepositoryProvider)
                .uploadAudioPlatformFile(
                  filename: file.name,
                  path: file.path,
                  bytes: file.bytes,
                );
          } on MediaUploadException catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(e.userMessage)),
              );
            }
            return null;
          }
        }

        return CreatorAudioUploadSheet(
          sheetTitle: existing == null ? 'Upload story audio' : 'Replace audio',
          canUpload: canUpload,
          initialPublicSourceUrl: initialUrl,
          initialDisplayName: existing?.displayName ?? '',
          initialDurationSeconds: existing?.durationSeconds,
          existingFileLabel: (existing?.localFileName ?? '').trim(),
          uploadAudio: uploadAudio,
        );
      },
    );
    if (!context.mounted || result == null) return;
    if (result.sourceUrl != null) {
      n.setStoryAudio(
        sourceUrlRaw: result.sourceUrl!,
        displayNameRaw: result.displayNameRaw,
        durationSeconds: result.durationSeconds,
      );
    } else if (result.pickedFile != null) {
      final f = result.pickedFile!;
      n.setStoryAudioFromPickedFile(
        pickedFileName: f.name,
        pickedPath: f.path,
        pickedSizeBytes: f.size,
        displayNameRaw: result.displayNameRaw,
        durationSeconds: result.durationSeconds,
      );
    }
  }
}

/// Shared Listening module UI used by:
/// - `/create/story/learn/audio` route screen
/// - embedded creator workspace panel (Story sentences host)
class StoryCreatorListeningModuleBody extends ConsumerWidget {
  const StoryCreatorListeningModuleBody({
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
    final a = draft.audio.storyAudio;
    final hasAudio = a?.isValidV1 == true;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideWorkspaceModuleTitle) ...[
          Text(
            useCompactModuleHeader
                ? 'Listening / Pronunciation'
                : 'Story-level audio (one file)',
            style: theme.textTheme.titleLarge?.copyWith(
              color: StoryCreatorAudioEditorScreen._ink,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Upload story audio for Full Learn, or leave empty for reading-only. '
          'Supported: mp3, m4a, wav',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: StoryCreatorAudioEditorScreen._muted,
            height: 1.45,
          ),
        ),
      ],
    );

    final list = ListView(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        padding.top,
        padding.right,
        showBottomActions ? 16 + bottomInset : padding.bottom,
      ),
      children: [
        header,
        const SizedBox(height: 16),
        if (!hasAudio) ...[
          _EmptyState(theme: theme),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () =>
                StoryCreatorAudioEditorScreen._showUpsertSheet(context, ref),
            icon: const Icon(Icons.audio_file_rounded),
            label: const Text('Choose audio file'),
          ),
        ] else ...[
          _AudioSummaryCard(asset: a!, theme: theme),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      StoryCreatorAudioEditorScreen._showUpsertSheet(
                    context,
                    ref,
                    existing: a,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Replace audio'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok =
                        await StoryCreatorAudioEditorScreen._confirmRemove(
                            context);
                    if (ok != true) return;
                    n.clearStoryAudio();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove audio'),
                ),
              ),
            ],
          ),
        ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No story audio yet',
              style: theme.textTheme.titleSmall?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1917),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an audio file for this story. '
              'Supported: mp3, m4a, wav',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: const Color(0xFF5C5A55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioSummaryCard extends StatelessWidget {
  const _AudioSummaryCard({required this.asset, required this.theme});

  final StoryAudioAsset asset;
  final ThemeData theme;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final name = (asset.displayName ?? '').trim();
    final fileName = (asset.localFileName ?? '').trim();
    final url = (asset.sourceUrl ?? '').trim();
    final dur = asset.durationSeconds;
    final status =
        asset.hasUploadedSourceUrl ? 'Saved online' : 'Draft on device';

    String durLabel(int s) {
      final m = s ~/ 60;
      final r = s % 60;
      return '${m}m ${r.toString().padLeft(2, '0')}s';
    }

    String subtitleLine() {
      if (fileName.isNotEmpty) return fileName;
      if (asset.hasUploadedSourceUrl && url.isNotEmpty) {
        if (url.length <= 56) return url;
        return '${url.substring(0, 53)}…';
      }
      if (url.isNotEmpty) return url;
      return 'Audio attached';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current audio',
              style: theme.textTheme.labelLarge?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (name.isNotEmpty) ...[
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              subtitleLine(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  asset.hasUploadedSourceUrl
                      ? Icons.cloud_done_rounded
                      : Icons.attachment_rounded,
                  size: 18,
                  color: _muted,
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (asset.localSizeBytes != null &&
                    asset.localSizeBytes! > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    '• ${_formatBytes(asset.localSizeBytes!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (dur != null && dur > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: _muted),
                  const SizedBox(width: 8),
                  Text(
                    durLabel(dur),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
