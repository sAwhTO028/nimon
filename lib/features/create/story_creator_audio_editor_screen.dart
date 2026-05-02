import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_route_sync_listener.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 creator editor for one story-level audio asset (upload-first).
class StoryCreatorAudioEditorScreen extends ConsumerWidget {
  const StoryCreatorAudioEditorScreen({super.key});

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  static const _allowedAudioExts = {'mp3', 'm4a', 'wav'};

  static String? _validatePickedAudioExt(PlatformFile f) {
    final ext = (f.extension ?? '').trim().toLowerCase();
    if (ext.isEmpty || !_allowedAudioExts.contains(ext)) {
      return 'Unsupported audio type. Use mp3, m4a, or wav.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handleCreatorBack() => unawaited(handleCreatorBackPressed(context, ref));

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
    final result = await showModalBottomSheet<_AudioUpsertResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F3EA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _AudioUpsertSheet(
          title: existing == null ? 'Add audio' : 'Replace audio',
          submitLabel: existing == null ? 'Add audio' : 'Save replacement',
          existingFileLabel: (existing?.localFileName ?? '').trim(),
          initialDisplayName: existing?.displayName ?? '',
          initialDurationSeconds: existing?.durationSeconds,
        );
      },
    );
    if (!context.mounted || result == null) return;
    n.setStoryAudioFromPickedFile(
      pickedFileName: result.pickedFile.name,
      pickedPath: result.pickedFile.path,
      pickedSizeBytes: result.pickedFile.size,
      displayNameRaw: result.displayNameRaw,
      durationSeconds: result.durationSeconds,
    );
  }
}

class _AudioUpsertResult {
  const _AudioUpsertResult({
    required this.pickedFile,
    required this.displayNameRaw,
    required this.durationSeconds,
  });

  final PlatformFile pickedFile;
  final String displayNameRaw;
  final int? durationSeconds;
}

class _AudioUpsertSheet extends StatefulWidget {
  const _AudioUpsertSheet({
    required this.title,
    required this.submitLabel,
    required this.existingFileLabel,
    required this.initialDisplayName,
    required this.initialDurationSeconds,
  });

  final String title;
  final String submitLabel;
  final String existingFileLabel;
  final String initialDisplayName;
  final int? initialDurationSeconds;

  @override
  State<_AudioUpsertSheet> createState() => _AudioUpsertSheetState();
}

class _AudioUpsertSheetState extends State<_AudioUpsertSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durCtrl;

  String? _error;
  PlatformFile? _picked;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayName);
    _durCtrl = TextEditingController(
      text: widget.initialDurationSeconds?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (!mounted) return;
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav'],
      withData: kIsWeb,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final err = StoryCreatorAudioEditorScreen._validatePickedAudioExt(f);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _picked = f);
  }

  void _submit() {
    final f = _picked;
    if (f == null) {
      setState(() => _error = 'Please choose an audio file.');
      return;
    }
    final rawDur = _durCtrl.text.trim();
    int? seconds;
    if (rawDur.isNotEmpty) {
      seconds = int.tryParse(rawDur);
      if (seconds == null || seconds <= 0) {
        setState(
          () =>
              _error = 'Duration must be a positive number (seconds).',
        );
        return;
      }
    }
    Navigator.pop<_AudioUpsertResult?>(
      context,
      _AudioUpsertResult(
        pickedFile: f,
        displayNameRaw: _nameCtrl.text,
        durationSeconds: seconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final existingLabel = widget.existingFileLabel;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: StoryCreatorAudioEditorScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attach one full-story audio file for listening practice. '
              'You can replace or remove it later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoryCreatorAudioEditorScreen._muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Audio file',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: StoryCreatorAudioEditorScreen._ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _picked == null ? 'Choose file' : 'Change file',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _picked?.name ??
                          (existingLabel.isNotEmpty
                              ? existingLabel
                              : 'No file selected'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: StoryCreatorAudioEditorScreen._muted,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
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
              controller: _nameCtrl,
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
              controller: _durCtrl,
              decoration: const InputDecoration(
                labelText: 'Duration (seconds, optional)',
                hintText: 'e.g. 95',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.submitLabel),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop<_AudioUpsertResult?>(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
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

