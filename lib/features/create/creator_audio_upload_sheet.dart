import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/story_creator_public_audio_url.dart';

/// Result of [CreatorAudioUploadSheet]; applied by [StoryCreatorAudioEditorScreen].
class AudioUpsertResult {
  const AudioUpsertResult({
    this.sourceUrl,
    this.pickedFile,
    required this.displayNameRaw,
    required this.durationSeconds,
  });

  final String? sourceUrl;
  final PlatformFile? pickedFile;
  final String displayNameRaw;
  final int? durationSeconds;
}

enum _AudioSheetPhase { pick, uploading, success }

/// Release-friendly “add / replace story audio” bottom sheet.
///
/// Primary flow: choose file → upload → success summary → **Add audio to story** / replace / remove.
///
/// URL entry and local-only attach appear only when [showAdvancedOptions] is true
/// (normally via `--dart-define=NIMON_CREATOR_AUDIO_ADVANCED=true`).
class CreatorAudioUploadSheet extends StatefulWidget {
  const CreatorAudioUploadSheet({
    super.key,
    required this.sheetTitle,
    required this.canUpload,
    required this.uploadAudio,
    required this.initialPublicSourceUrl,
    required this.initialDisplayName,
    required this.initialDurationSeconds,
    required this.existingFileLabel,

    /// Debug / widget tests only: skip pick+upload and open on success (must be null in release builds).
    this.debugSuccessResponse,

    /// Surfaces optional metadata + URL / local-only flows (default: compile-time flag).
    this.showAdvancedOptions =
        RemoteBackendConfig.creatorAudioAdvancedUxEnabled,
  });

  static const ink = Color(0xFF1A1917);
  static const muted = Color(0xFF5C5A55);

  static const allowedAudioExts = {'mp3', 'm4a', 'wav'};

  static String? validatePickedAudioExt(PlatformFile f) {
    final ext = (f.extension ?? '').trim().toLowerCase();
    if (ext.isEmpty || !allowedAudioExts.contains(ext)) {
      return 'Unsupported audio type. Use mp3, m4a, or wav.';
    }
    return null;
  }

  final String sheetTitle;
  final bool canUpload;
  final Future<MediaUploadResponse?> Function(PlatformFile file) uploadAudio;

  final String initialPublicSourceUrl;
  final String initialDisplayName;
  final int? initialDurationSeconds;
  final String existingFileLabel;

  /// When set in debug mode, shows the post-upload success UI without picking (tests only).
  final MediaUploadResponse? debugSuccessResponse;

  /// When false (default release), first screen is upload-only.
  final bool showAdvancedOptions;

  @override
  State<CreatorAudioUploadSheet> createState() =>
      _CreatorAudioUploadSheetState();
}

class _CreatorAudioUploadSheetState extends State<CreatorAudioUploadSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durCtrl;

  _AudioSheetPhase _phase = _AudioSheetPhase.pick;
  PlatformFile? _advancedLocalPicked;
  MediaUploadResponse? _uploadResult;

  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialPublicSourceUrl);
    _nameCtrl = TextEditingController(text: widget.initialDisplayName);
    _durCtrl = TextEditingController(
      text: widget.initialDurationSeconds?.toString() ?? '',
    );
    if (kDebugMode && widget.debugSuccessResponse != null) {
      _uploadResult = widget.debugSuccessResponse;
      _phase = _AudioSheetPhase.success;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  int? _parseDuration() {
    final rawDur = _durCtrl.text.trim();
    if (rawDur.isEmpty) return null;
    final seconds = int.tryParse(rawDur);
    if (seconds == null || seconds <= 0) return -1;
    return seconds;
  }

  void _submitPublicUrl() {
    setState(() => _error = null);
    final msg = publicAudioSourceUrlValidationMessage(_urlCtrl.text);
    if (msg != null) {
      setState(() => _error = msg);
      return;
    }
    final dur = _parseDuration();
    if (dur == -1) {
      setState(() =>
          _error = 'Enter a positive duration in seconds, or leave blank.');
      return;
    }
    Navigator.pop<AudioUpsertResult>(
      context,
      AudioUpsertResult(
        sourceUrl: _urlCtrl.text.trim(),
        pickedFile: null,
        displayNameRaw: _nameCtrl.text,
        durationSeconds: dur,
      ),
    );
  }

  Future<void> _pickPrimaryAndUpload() async {
    if (!widget.canUpload) return;
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
    final err = CreatorAudioUploadSheet.validatePickedAudioExt(f);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _advancedLocalPicked = null;
      _phase = _AudioSheetPhase.uploading;
      _error = null;
    });
    await _runUpload(f);
  }

  Future<void> _runUpload(PlatformFile f) async {
    final r = await widget.uploadAudio(f);
    if (!mounted) return;
    if (r == null) {
      setState(() {
        _phase = _AudioSheetPhase.pick;
      });
      return;
    }
    setState(() {
      _uploadResult = r;
      _phase = _AudioSheetPhase.success;
    });
  }

  Future<void> _pickAdvancedLocal() async {
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
    final err = CreatorAudioUploadSheet.validatePickedAudioExt(f);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _advancedLocalPicked = f;
    });
  }

  void _submitLocalOnly() {
    setState(() => _error = null);
    final f = _advancedLocalPicked;
    if (f == null) {
      setState(() => _error = 'Choose a file in Advanced options first.');
      return;
    }
    final dur = _parseDuration();
    if (dur == -1) {
      setState(
        () => _error = 'Enter a positive duration in seconds, or leave blank.',
      );
      return;
    }
    Navigator.pop<AudioUpsertResult>(
      context,
      AudioUpsertResult(
        sourceUrl: null,
        pickedFile: f,
        displayNameRaw: _nameCtrl.text,
        durationSeconds: dur,
      ),
    );
  }

  void _popSuccessResult() {
    final r = _uploadResult;
    if (r == null) return;
    final rawDur = _durCtrl.text.trim();
    int? manualDur;
    if (rawDur.isNotEmpty) {
      final s = int.tryParse(rawDur);
      if (s == null || s <= 0) {
        setState(
          () =>
              _error = 'Enter a positive duration in seconds, or leave blank.',
        );
        return;
      }
      manualDur = s;
    }
    final merged = manualDur ?? r.durationSeconds;
    Navigator.pop<AudioUpsertResult>(
      context,
      AudioUpsertResult(
        sourceUrl: r.url,
        pickedFile: null,
        displayNameRaw: _nameCtrl.text,
        durationSeconds: merged,
      ),
    );
  }

  void _resetFromSuccess() {
    setState(() {
      _phase = _AudioSheetPhase.pick;
      _uploadResult = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.sheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: CreatorAudioUploadSheet.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_phase == _AudioSheetPhase.pick) ...[
              Text(
                'Choose an audio file for this story.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supported: mp3, m4a, wav',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose a file first. After upload, add it to your story.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (!widget.canUpload) ...[
                Text(
                  'Sign in to upload audio.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: CreatorAudioUploadSheet.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Choose audio file'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _pickPrimaryAndUpload,
                  icon: const Icon(Icons.audio_file_rounded),
                  label: const Text('Choose audio file'),
                ),
              ],
              if (widget.showAdvancedOptions) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text(
                    'Optional details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CreatorAudioUploadSheet.ink,
                    ),
                  ),
                  subtitle: Text(
                    'Display name and length',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CreatorAudioUploadSheet.muted,
                    ),
                  ),
                  initiallyExpanded: false,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Display name (optional)',
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
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                const SizedBox(height: 4),
                ExpansionTile(
                  title: Text(
                    'Advanced options',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CreatorAudioUploadSheet.ink,
                    ),
                  ),
                  subtitle: Text(
                    'Public link or local-only draft',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CreatorAudioUploadSheet.muted,
                    ),
                  ),
                  initiallyExpanded: false,
                  children: [
                    Text(
                      'Public audio URL',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: CreatorAudioUploadSheet.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'https://… (link to audio file)',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _submitPublicUrl,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Save public URL'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attach without uploading',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: CreatorAudioUploadSheet.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Draft preview on this device only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CreatorAudioUploadSheet.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickAdvancedLocal,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(
                        _advancedLocalPicked == null
                            ? 'Choose file'
                            : 'Change file',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _advancedLocalPicked?.name ??
                          'No file selected for local attach',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CreatorAudioUploadSheet.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _submitLocalOnly,
                      icon: const Icon(Icons.folder_special_rounded),
                      label: const Text('Attach without uploading'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ],
            if (_phase == _AudioSheetPhase.uploading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Uploading…',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: CreatorAudioUploadSheet.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  height: 1.35,
                ),
              ),
            ],
            if (_phase == _AudioSheetPhase.success) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload complete',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: CreatorAudioUploadSheet.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SuccessSummary(
                response: _uploadResult!,
                nameCtrl: _nameCtrl,
              ),
              const SizedBox(height: 12),
              Text(
                'Tap Add audio to story to attach this file to your draft.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Optional details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CreatorAudioUploadSheet.ink,
                  ),
                ),
                initiallyExpanded: false,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display name (optional)',
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
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _popSuccessResult,
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('Add audio to story'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _resetFromSuccess,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Replace audio'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop<AudioUpsertResult>(context, null),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove audio'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _phase == _AudioSheetPhase.uploading
                  ? null
                  : () => Navigator.pop<AudioUpsertResult>(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSummary extends StatelessWidget {
  const _SuccessSummary({
    required this.response,
    required this.nameCtrl,
  });

  final MediaUploadResponse response;
  final TextEditingController nameCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = nameCtrl.text.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              response.originalName.isNotEmpty
                  ? response.originalName
                  : 'Audio file',
              style: theme.textTheme.titleSmall?.copyWith(
                color: CreatorAudioUploadSheet.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Title: $name',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              _sizeLabel(response.sizeBytes),
              style: theme.textTheme.bodySmall?.copyWith(
                color: CreatorAudioUploadSheet.muted,
              ),
            ),
            if (response.durationSeconds != null &&
                response.durationSeconds! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Length: ${response.durationSeconds} sec',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CreatorAudioUploadSheet.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
