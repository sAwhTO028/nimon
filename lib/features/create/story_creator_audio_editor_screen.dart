import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_route_sync.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 creator editor for one story-level audio asset (upload-first).
class StoryCreatorAudioEditorScreen extends ConsumerWidget {
  const StoryCreatorAudioEditorScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    syncCreatorDrawerSessionFromContext(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening / Audio'),
        leading: NimonBackButton(onPressed: () => context.pop()),
      ),
      body: StoryCreatorListeningModuleBody(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        showBottomActions: true,
        showLearnExitButton: true,
        useCompactModuleHeader: false,
        onExit: () => context.pop(),
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
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final durCtrl = TextEditingController(
      text: existing?.durationSeconds?.toString() ?? '',
    );
    String? error;
    PlatformFile? picked;

    final existingFileLabel = (existing?.localFileName ?? '').trim();

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
            Future<void> pickFile() async {
              setSheetState(() => error = null);
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                type: FileType.custom,
                allowedExtensions: const ['mp3', 'm4a', 'wav'],
                withData: kIsWeb,
              );
              if (result == null || result.files.isEmpty) return;
              final f = result.files.single;
              final ext = (f.extension ?? '').trim().toLowerCase();
              if (ext.isEmpty || !const {'mp3', 'm4a', 'wav'}.contains(ext)) {
                setSheetState(() => error = 'Unsupported audio type. Use mp3, m4a, or wav.');
                return;
              }
              setSheetState(() => picked = f);
            }

            void save() {
              final f = picked;
              if (f == null) {
                setSheetState(() => error = 'Please choose an audio file.');
                return;
              }
              final rawDur = durCtrl.text.trim();
              int? seconds;
              if (rawDur.isNotEmpty) {
                seconds = int.tryParse(rawDur);
                if (seconds == null || seconds <= 0) {
                  setSheetState(() => error = 'Duration must be a positive number (seconds).');
                  return;
                }
              }
              n.setStoryAudioFromPickedFile(
                pickedFileName: f.name,
                pickedPath: f.path,
                pickedSizeBytes: f.size,
                displayNameRaw: nameCtrl.text,
                durationSeconds: seconds,
              );
              Navigator.pop(ctx2);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'Add audio' : 'Replace audio',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attach one full-story audio file for listening practice. '
                      'You can replace or remove it later.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Audio file',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(
                                picked == null ? 'Choose file' : 'Change file',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              picked?.name ??
                                  (existingFileLabel.isNotEmpty
                                      ? existingFileLabel
                                      : 'No file selected'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _muted,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Display name (optional)',
                        hintText: 'e.g. Full story narration',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duration (seconds, optional)',
                        hintText: 'e.g. 95',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: save,
                      child: Text(existing == null ? 'Add audio' : 'Save replacement'),
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

    nameCtrl.dispose();
    durCtrl.dispose();
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
          'Attach one full-story audio source for listening practice. '
          'You can replace or remove it later. '
          'Audio is optional for Reading Only, but required for Full Learn completion.',
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
            onPressed: () => StoryCreatorAudioEditorScreen._showUpsertSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Upload audio'),
          ),
        ] else ...[
          _AudioSummaryCard(asset: a!, theme: theme),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => StoryCreatorAudioEditorScreen._showUpsertSheet(
                    context,
                    ref,
                    existing: a,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Replace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok =
                        await StoryCreatorAudioEditorScreen._confirmRemove(context);
                    if (ok != true) return;
                    n.clearStoryAudio();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
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
                    child: const Text('Back to Learn modules'),
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
              'No audio attached yet',
              style: theme.textTheme.titleSmall?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1917),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attach one full-story audio file for listening practice.',
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
    final dur = asset.durationSeconds;
    final status = asset.hasUploadedSourceUrl ? 'Uploaded' : 'Attached';

    String durLabel(int s) {
      final m = s ~/ 60;
      final r = s % 60;
      return '${m}m ${r.toString().padLeft(2, '0')}s';
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
              fileName.isNotEmpty ? fileName : 'Audio file attached',
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
                if (asset.localSizeBytes != null && asset.localSizeBytes! > 0) ...[
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
    if (bytes < 1024) return '${bytes} B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

