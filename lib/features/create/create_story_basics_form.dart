import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/create/story_basics_cover_upload_outcome.dart';
import 'package:nimon/features/create/story_basics_remote_cover_url.dart';
import 'package:nimon/core/validation/form_validation_adapter.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/story_validators.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Payload for [StoryCreatorDraftNotifier.applyBasics] built from the unified form.
class StoryBasicsApplyPayload {
  const StoryBasicsApplyPayload({
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.promptSourceNote,
    this.targetDurationBandKey,
    this.coverImageUrl,
  });

  final String title;
  final String category;
  final String level;
  final String description;
  final String promptSourceNote;
  final String? targetDurationBandKey;
  final String? coverImageUrl;
}

/// Single Story Basics form UI: same layout as the dock **Create** step 1 (preview, dots, fields, cover).
///
/// Used by [CreateScreen], [StoryCreatorBasicsScreen], and edit-from-review.
class CreateStoryBasicsForm extends StatefulWidget {
  const CreateStoryBasicsForm({
    super.key,
    this.initialDraft,
    this.progressSheetActionLabel = 'CREATE',
    this.onFieldsChanged,
    this.onDraftFieldsChanged,
    this.onCoverUpload,
    this.coverUploadAllowed = true,
  });

  /// When non-null, fields are seeded once (edit / creator basics).
  final CreatorStoryV1? initialDraft;

  /// Shown in the progress bottom sheet (e.g. CREATE vs Save changes).
  final String progressSheetActionLabel;

  /// Notifies parent (e.g. to refresh CREATE / Save enabled state).
  final VoidCallback? onFieldsChanged;

  /// Fires on any meaningful field change with dirty detection (V1 autosave trigger).
  final ValueChanged<StoryBasicsDraftFields>? onDraftFieldsChanged;

  /// When set, a gallery pick runs M5c remote upload; on success [StoryBasics.coverImageUrl] uses the returned URL.
  final Future<StoryBasicsCoverUploadOutcome> Function(XFile file)?
      onCoverUpload;

  /// When [onCoverUpload] is set, whether remote upload is allowed (signed-in session).
  /// When false, gallery opens only after sign-in for upload; otherwise shows a short sign-in message.
  final bool coverUploadAllowed;

  @override
  State<CreateStoryBasicsForm> createState() => CreateStoryBasicsFormState();
}

class StoryBasicsDraftFields {
  const StoryBasicsDraftFields({
    required this.title,
    required this.description,
    required this.level,
    required this.category,
    required this.durationLabel,
    required this.coverLocalPath,
    required this.coverNetworkUrl,
    required this.coverExplicitlyCleared,
    required this.isDirty,
  });

  final String title;
  final String description;
  final String? level;
  final String? category;
  final String? durationLabel;
  final String? coverLocalPath;
  final String? coverNetworkUrl;
  final bool coverExplicitlyCleared;
  final bool isDirty;
}

class CreateStoryBasicsFormState extends State<CreateStoryBasicsForm> {
  static const _durations = ['3–5 mins', '5–7 mins', '7–9 mins'];
  static const _pageHPadding = 12.0;
  static const _sectionGap = 10.0;
  static const _primarySectionGap = 12.0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _jlptLevels = const ['N5', 'N4', 'N3', 'N2', 'N1'];
  final List<String> _categories = const [
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery',
  ];

  String? _selectedLevel;
  String? _selectedCategory;
  String? _selectedDuration;

  /// Local gallery path for preview; optional http(s) local path passes through to draft URL.
  String? _coverLocalPath;

  /// Picked image bytes (Flutter web — no [File] / [Image.file] for local picks).
  Uint8List? _coverWebBytes;

  /// Remote cover from existing draft (preview only until user replaces).
  String? _coverNetworkUrl;

  bool _coverUploading = false;

  /// Shown when the thumbnail is a **local** pick that is not stored as a remote URL.
  String? _coverLocalOnlyNote;

  bool _seeded = false;
  StoryBasicsDraftFields? _seedSnapshot;
  String _existingPromptSourceNote = '';

  /// True after user taps clear on the cover thumbnail (distinct from “replace”).
  bool _coverExplicitlyCleared = false;

  /// Prevents debounced autosave while snapshot/controllers are mid-seed.
  bool _suppressDraftNotifications = false;

  ValidationIssue? _titleBlockingIssue;
  ValidationIssue? _descriptionBlockingIssue;
  ValidationIssue? _titleWarningIssue;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seeded) return;
      if (widget.initialDraft != null) {
        _seedFromDraft(widget.initialDraft!);
        _seeded = true;
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CreateStoryBasicsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialDraft;
    if (next == null) return;
    final prevId = oldWidget.initialDraft?.id.trim() ?? '';
    final nextId = next.id.trim();
    if (!_seeded || prevId != nextId) {
      _seedFromDraft(next);
      _seeded = true;
      setState(() {});
    }
  }

  void _onFormChanged() {
    _notifyParent();
    _notifyDraftFieldsChanged();
    if (!mounted) return;
    final titleR =
        validateStoryTitle(_titleController.text, ValidationMode.draft);
    final descR = validateStoryDescription(
      _descriptionController.text,
      ValidationMode.draft,
    );
    ValidationIssue? titleWarnIssue;
    for (final i in titleR.issues) {
      if (i.field == 'story.title' &&
          i.severity == ValidationSeverity.warning) {
        titleWarnIssue = i;
        break;
      }
    }
    final titleErrIssue = firstBlockingIssueForField(titleR, 'story.title');
    final descErrIssue = firstBlockingIssueForField(descR, 'story.description');
    setState(() {
      _titleBlockingIssue = titleErrIssue;
      _descriptionBlockingIssue = descErrIssue;
      _titleWarningIssue = titleErrIssue == null ? titleWarnIssue : null;
    });
  }

  void _notifyParent() => widget.onFieldsChanged?.call();

  void _notifyDraftFieldsChanged() {
    final cb = widget.onDraftFieldsChanged;
    if (cb == null || _suppressDraftNotifications) return;

    _seedSnapshot ??= StoryBasicsDraftFields(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      level: _selectedLevel,
      category: _selectedCategory,
      durationLabel: _selectedDuration,
      coverLocalPath: _coverLocalPath,
      coverNetworkUrl: _coverNetworkUrl,
      coverExplicitlyCleared: _coverExplicitlyCleared,
      isDirty: false,
    );

    bool changed(String a, String b) => a.trim() != b.trim();
    bool changedOpt(String? a, String? b) =>
        (a ?? '').trim() != (b ?? '').trim();

    final s = _seedSnapshot!;
    final dirty = changed(_titleController.text, s.title) ||
        changed(_descriptionController.text, s.description) ||
        changedOpt(_selectedLevel, s.level) ||
        changedOpt(_selectedCategory, s.category) ||
        changedOpt(_selectedDuration, s.durationLabel) ||
        changedOpt(_coverLocalPath, s.coverLocalPath) ||
        changedOpt(_coverNetworkUrl, s.coverNetworkUrl) ||
        (_coverExplicitlyCleared != s.coverExplicitlyCleared);

    cb(
      StoryBasicsDraftFields(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        level: _selectedLevel,
        category: _selectedCategory,
        durationLabel: _selectedDuration,
        coverLocalPath: _coverLocalPath,
        coverNetworkUrl: _coverNetworkUrl,
        coverExplicitlyCleared: _coverExplicitlyCleared,
        isDirty: dirty,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _seedFromDraft(CreatorStoryV1 d) {
    _suppressDraftNotifications = true;
    try {
      final key = d.basics.targetDurationBandKey?.trim();
      final durationLabel = switch (key) {
        '3_5' => '3–5 mins',
        '5_7' => '5–7 mins',
        '7_9' => '7–9 mins',
        _ => null,
      };
      final url = d.basics.coverImageUrl?.trim();
      final netCover = (url != null &&
              url.isNotEmpty &&
              (url.startsWith('http://') || url.startsWith('https://')))
          ? url
          : null;

      _seedSnapshot = StoryBasicsDraftFields(
        title: d.title.trim(),
        description: d.description.trim(),
        level: d.level.isEmpty ? null : d.level,
        category: d.category.isEmpty ? null : d.category,
        durationLabel: durationLabel,
        coverLocalPath: null,
        coverNetworkUrl: netCover,
        coverExplicitlyCleared: false,
        isDirty: false,
      );

      _titleController.text = d.title;
      _descriptionController.text = d.description;
      _selectedLevel = d.level.isEmpty ? null : d.level;
      _selectedCategory = d.category.isEmpty ? null : d.category;
      _selectedDuration = durationLabel;
      _existingPromptSourceNote = d.promptSourceNote;
      _coverNetworkUrl = netCover;
      _coverLocalPath = null;
      _coverWebBytes = null;
      _coverExplicitlyCleared = false;
      _coverLocalOnlyNote = null;
      _coverUploading = false;
    } finally {
      _suppressDraftNotifications = false;
    }
    _onFormChanged();
  }

  bool get isStep1Complete =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      (_selectedLevel ?? '').isNotEmpty &&
      (_selectedCategory ?? '').isNotEmpty &&
      (_selectedDuration ?? '').isNotEmpty;

  int get step1RequiredFilledCount {
    var n = 0;
    if (_titleController.text.trim().isNotEmpty) n++;
    if (_descriptionController.text.trim().isNotEmpty) n++;
    if ((_selectedLevel ?? '').isNotEmpty) n++;
    if ((_selectedCategory ?? '').isNotEmpty) n++;
    if ((_selectedDuration ?? '').isNotEmpty) n++;
    return n;
  }

  Future<void> _pickCover() async {
    final upload = widget.onCoverUpload;
    if (upload != null && !widget.coverUploadAllowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to upload cover images.'),
        ),
      );
      return;
    }

    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!mounted || x == null) return;

    if (upload != null) {
      setState(() {
        _coverUploading = true;
        _coverLocalOnlyNote = null;
      });
      try {
        final outcome = await upload(x);
        if (!mounted) return;
        if (outcome.isSuccess) {
          final url = outcome.response!.url;
          setState(() {
            _coverExplicitlyCleared = false;
            _coverLocalPath = null;
            _coverWebBytes = null;
            _coverNetworkUrl = url;
            _coverUploading = false;
            _coverLocalOnlyNote = null;
          });
        } else {
          await _seedLocalCoverPreview(x);
          if (!mounted) return;
          setState(() {
            _coverExplicitlyCleared = false;
            _coverUploading = false;
            _coverLocalOnlyNote = outcome.inlineHint;
          });
        }
      } catch (_) {
        if (!mounted) return;
        await _seedLocalCoverPreview(x);
        if (!mounted) return;
        setState(() {
          _coverExplicitlyCleared = false;
          _coverUploading = false;
          _coverLocalOnlyNote = 'Upload failed. Try again.';
        });
      }
      _notifyParent();
      _notifyDraftFieldsChanged();
      return;
    }

    await _seedLocalCoverPreview(x);
    if (!mounted) return;
    setState(() {
      _coverExplicitlyCleared = false;
      _coverLocalOnlyNote = 'Local preview only.';
    });
    _notifyParent();
    _notifyDraftFieldsChanged();
  }

  Future<void> _seedLocalCoverPreview(XFile x) async {
    if (kIsWeb) {
      final p = x.path.trim();
      Uint8List? b;
      if (p.isEmpty ||
          p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:')) {
        b = null;
      } else {
        b = await x.readAsBytes();
      }
      setState(() {
        _coverLocalPath = p.isNotEmpty ? p : null;
        _coverWebBytes = b;
        _coverNetworkUrl = null;
      });
    } else {
      setState(() {
        _coverLocalPath = x.path;
        _coverWebBytes = null;
        _coverNetworkUrl = null;
      });
    }
  }

  void _clearCover() {
    setState(() {
      _coverExplicitlyCleared = true;
      _coverLocalPath = null;
      _coverWebBytes = null;
      _coverNetworkUrl = null;
      _coverLocalOnlyNote = null;
    });
    _notifyParent();
    _notifyDraftFieldsChanged();
  }

  String? _coverImageUrlForDraft() {
    return storyBasicsRemoteCoverUrl(
      coverLocalPath: _coverLocalPath,
      coverNetworkUrl: _coverNetworkUrl,
    );
  }

  static String _durationPromptLine(String duration) =>
      'Target duration: $duration';

  /// Returns null if required fields are incomplete.
  StoryBasicsApplyPayload? buildPayloadIfValid() {
    if (!isStep1Complete) return null;
    final duration = _selectedDuration!;
    final durationKey = switch (duration) {
      '3–5 mins' => '3_5',
      '5–7 mins' => '5_7',
      '7–9 mins' => '7_9',
      _ => '',
    };
    return StoryBasicsApplyPayload(
      title: _titleController.text.trim(),
      category: _selectedCategory!,
      level: _selectedLevel!,
      description: _descriptionController.text.trim(),
      // Prompt/source note is not editable on this page in V1. Preserve existing
      // note for edits; for new drafts, keep a minimal duration line.
      promptSourceNote: _existingPromptSourceNote.trim().isNotEmpty
          ? _existingPromptSourceNote
          : _durationPromptLine(duration),
      targetDurationBandKey: durationKey.isEmpty ? null : durationKey,
      coverImageUrl: _coverImageUrlForDraft(),
    );
  }

  void showProgressBottomSheet() {
    _showStep1StatusBottomSheet(Theme.of(context));
  }

  bool get _hasCoverThumbnail {
    if (kIsWeb) {
      final w = _coverWebBytes;
      if (w != null && w.isNotEmpty) return true;
    }
    final lp = _coverLocalPath?.trim();
    if (lp != null && lp.isNotEmpty) return true;
    final n = _coverNetworkUrl?.trim();
    return n != null && n.isNotEmpty;
  }

  Widget? _buildThumbnailImage(BoxFit fit) {
    final n = _coverNetworkUrl?.trim();
    if (n != null && n.isNotEmpty) {
      return Image.network(
        n,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    if (kIsWeb) {
      final w = _coverWebBytes;
      if (w != null && w.isNotEmpty) {
        return Image.memory(w, fit: fit);
      }
      final lpw = _coverLocalPath?.trim();
      if (lpw != null && lpw.isNotEmpty) {
        if (lpw.startsWith('http://') ||
            lpw.startsWith('https://') ||
            lpw.startsWith('blob:')) {
          return Image.network(
            lpw,
            fit: fit,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined),
          );
        }
        return const Icon(Icons.broken_image_outlined);
      }
      return null;
    }
    final lp = _coverLocalPath?.trim();
    if (lp != null && lp.isNotEmpty) {
      return Image.file(File(lp), fit: fit);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerLowest;
    return ColoredBox(
      color: surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _pageHPadding,
          14,
          _pageHPadding,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCoverSection(theme),
            const SizedBox(height: _primarySectionGap),
            _buildLabeledCard(
              theme,
              title: 'Title',
              requiredMark: true,
              child: TextField(
                controller: _titleController,
                maxLength: 80,
                decoration: _fieldDecoration(
                  theme,
                  hintText: 'Story title',
                  counterText: '',
                ).copyWith(
                  errorText: _titleBlockingIssue != null
                      ? validationIssueDisplayMessageLocalized(
                          context,
                          _titleBlockingIssue!,
                        )
                      : null,
                  helperText: _titleWarningIssue != null
                      ? validationIssueDisplayMessageLocalized(
                          context,
                          _titleWarningIssue!,
                        )
                      : null,
                ),
                style: theme.textTheme.bodyLarge,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            SizedBox(height: _sectionGap),
            _buildLabeledCard(
              theme,
              title: 'Story description',
              requiredMark: true,
              child: TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: _fieldDecoration(
                  theme,
                  hintText: 'What readers should expect…',
                ).copyWith(
                  errorText: _descriptionBlockingIssue != null
                      ? validationIssueDisplayMessageLocalized(
                          context,
                          _descriptionBlockingIssue!,
                        )
                      : null,
                ),
                style: theme.textTheme.bodyMedium,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: _primarySectionGap),
            _buildLabeledCard(
              theme,
              title: 'Level',
              requiredMark: true,
              child: DropdownButtonFormField<String>(
                value: _selectedLevel,
                items: [
                  for (final l in _jlptLevels)
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: (v) {
                  setState(() => _selectedLevel = v);
                  _notifyParent();
                },
                decoration: _fieldDecoration(theme, hintText: 'JLPT level'),
              ),
            ),
            const SizedBox(height: _sectionGap),
            _buildLabeledCard(
              theme,
              title: 'Category',
              requiredMark: true,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  setState(() => _selectedCategory = v);
                  _notifyParent();
                },
                decoration: _fieldDecoration(theme, hintText: 'Category'),
              ),
            ),
            const SizedBox(height: _sectionGap),
            _buildLabeledCard(
              theme,
              title: 'Duration',
              requiredMark: true,
              child: DropdownButtonFormField<String>(
                value: _selectedDuration,
                items: [
                  for (final d in _durations)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) {
                  setState(() => _selectedDuration = v);
                  _notifyParent();
                },
                decoration: _fieldDecoration(
                  theme,
                  hintText: 'Reading time',
                ),
              ),
            ),
            SizedBox(height: _sectionGap),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    String? hintText,
    String? counterText,
  }) {
    final cs = theme.colorScheme;
    final outline = cs.outlineVariant.withValues(alpha: 0.55);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surface,
      hintText: hintText,
      counterText: counterText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildLabeledCard(
    ThemeData theme, {
    required String title,
    required bool requiredMark,
    required Widget child,
  }) {
    final cs = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface.withValues(alpha: 0.86),
      letterSpacing: 0.1,
    );
    final requiredStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.primary.withValues(alpha: 0.95),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: labelStyle,
              ),
            ),
            if (requiredMark)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text('Required', style: requiredStyle),
              ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCoverSection(ThemeData theme) {
    final hasLocal =
        _coverLocalPath != null && _coverLocalPath!.trim().isNotEmpty;
    final hasNet =
        _coverNetworkUrl != null && _coverNetworkUrl!.trim().isNotEmpty;
    final hasWebBytes =
        kIsWeb && _coverWebBytes != null && _coverWebBytes!.isNotEmpty;
    final hasThumb = hasLocal || hasNet || hasWebBytes;
    final thumbWidget = _buildThumbnailImage(BoxFit.cover);
    final cs = theme.colorScheme;
    const thumbW = 72.0;
    const thumbH = 72.0;

    final wantsRemote =
        widget.onCoverUpload != null && widget.coverUploadAllowed;
    final signedOutRemote =
        widget.onCoverUpload != null && !widget.coverUploadAllowed;
    final remoteSaved = hasNet && !_coverUploading;

    final titleStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface.withValues(alpha: 0.86),
      letterSpacing: 0.1,
    );
    final optionalStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    final thumbInteractive =
        !_coverUploading && !signedOutRemote ? _pickCover : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Upload a cover image',
                    style: titleStyle,
                  ),
                ),
                Text('Optional', style: optionalStyle),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Supported: JPG, PNG, WebP',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            if (_coverUploading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 8),
              Text(
                'Uploading…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: thumbInteractive,
                    child: SizedBox(
                      width: thumbW,
                      height: thumbH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasThumb && thumbWidget != null)
                            thumbWidget
                          else if (!_coverUploading)
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            ),
                          if (hasThumb &&
                              thumbWidget != null &&
                              !_coverUploading)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Tooltip(
                                message: 'Remove cover',
                                child: Material(
                                  color: cs.surface.withValues(alpha: 0.92),
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                      minHeight: 30,
                                    ),
                                    padding: EdgeInsets.zero,
                                    iconSize: 18,
                                    onPressed: _clearCover,
                                    icon: Icon(Icons.close, color: cs.error),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (signedOutRemote) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sign in to upload cover images.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (remoteSaved) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_done_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Saved online',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ] else if (hasThumb && !hasNet && !_coverUploading) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Local preview only',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onTertiaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_coverLocalOnlyNote != null &&
                            _coverLocalOnlyNote!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _coverLocalOnlyNote!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.error,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ] else if (!_coverUploading) ...[
                        Text(
                          wantsRemote
                              ? 'Adds a visual for your story.'
                              : 'Preview on this device only.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (hasThumb && !_coverUploading) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: signedOutRemote ? null : _pickCover,
                            child: const Text('Replace cover'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!hasThumb && !_coverUploading) ...[
              const SizedBox(height: 12),
              if (signedOutRemote)
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Choose cover image'),
                )
              else
                FilledButton.icon(
                  onPressed: thumbInteractive,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Choose cover image'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepPreviewCard(ThemeData theme) {
    final titleText = _titleController.text.trim();
    final descText = _descriptionController.text.trim();
    final level = _selectedLevel;
    final category = _selectedCategory;
    final duration = _selectedDuration;
    final cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 80,
                  child: _hasCoverThumbnail
                      ? (_buildThumbnailImage(BoxFit.cover) ??
                          ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              size: 26,
                              color: cs.onSurfaceVariant,
                            ),
                          ))
                      : ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_outlined,
                            size: 26,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Story basics',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titleText.isEmpty ? 'Untitled story' : titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleText.isEmpty
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descText.isEmpty
                          ? 'Description appears here as you type.'
                          : descText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: descText.isEmpty
                            ? cs.onSurfaceVariant
                            : cs.onSurface.withValues(alpha: 0.75),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPreviewMetaRow(
                      theme,
                      level: level,
                      category: category,
                      duration: duration,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewMetaRow(
    ThemeData theme, {
    required String? level,
    required String? category,
    required String? duration,
  }) {
    final hasAny = (level ?? '').isNotEmpty ||
        (category ?? '').isNotEmpty ||
        (duration ?? '').isNotEmpty;
    final cs = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final filled = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );

    if (!hasAny) {
      return Text(
        'Level · Category · Duration',
        style: muted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final parts = <String>[];
    if ((level ?? '').isNotEmpty) parts.add(level!);
    if ((category ?? '').isNotEmpty) parts.add(category!);
    if ((duration ?? '').isNotEmpty) parts.add(duration!);

    return Text(
      parts.join(' · '),
      style: filled,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showStep1StatusBottomSheet(ThemeData theme) {
    final action = widget.progressSheetActionLabel;
    final items = <({String label, bool done})>[
      (label: 'Title', done: _titleController.text.trim().isNotEmpty),
      (
        label: 'Story description',
        done: _descriptionController.text.trim().isNotEmpty,
      ),
      (label: 'Level', done: (_selectedLevel ?? '').isNotEmpty),
      (label: 'Category', done: (_selectedCategory ?? '').isNotEmpty),
      (label: 'Duration', done: (_selectedDuration ?? '').isNotEmpty),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final doneList = items.where((e) => e.done).toList();
        final todoList = items.where((e) => !e.done).toList();
        final mq = MediaQuery.of(ctx);
        final cs = theme.colorScheme;

        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Story basics — progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Done vs remaining before $action.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (doneList.isNotEmpty) ...[
                    Text(
                      'Completed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...doneList.map(
                      (e) => ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        minLeadingWidth: 28,
                        leading: Icon(
                          Icons.check_circle_rounded,
                          color: cs.tertiary,
                          size: 20,
                        ),
                        title: Text(
                          e.label,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (todoList.isNotEmpty) ...[
                    Text(
                      'Still needed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...todoList.map(
                      (e) => ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        minLeadingWidth: 28,
                        leading: Icon(
                          Icons.radio_button_unchecked,
                          color: cs.outline,
                          size: 20,
                        ),
                        title: Text(
                          e.label,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                  if (todoList.isEmpty && doneList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'All required fields are complete. You can continue.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cover is optional and does not affect required fields.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
