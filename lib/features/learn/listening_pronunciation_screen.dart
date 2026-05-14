import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/learn/learn_catalog_content_gate.dart';
import 'package:nimon/features/learn/learn_creator_module_tokens.dart';
import 'package:nimon/features/learn/learn_module_surface_tokens.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_published_snapshot_mappers.dart';
import 'package:nimon/features/learn/learn_published_snapshot_providers.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/features/learn/listening_transcript_models.dart';
import 'package:nimon/features/mono/mono_line_explanation_display.dart';
import 'package:nimon/features/learn/listening_transcript_from_published.dart';
import 'package:nimon/features/settings/settings_providers.dart';
import 'package:nimon/ui/reading/nimon_furigana_preview_style.dart';
import 'package:nimon/ui/reading/nimon_ruby_text.dart';
import 'package:nimon/ui/reading/nimon_translation_text.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Returns [StoryAudioDto.sourceUrl] only when it is `http://` or `https://`.
String? publishedStoryAudioHttpUrl(StoryAudioDto? audio) {
  if (audio == null) return null;
  final u = (audio.sourceUrl ?? '').trim();
  if (u.isEmpty) return null;
  final lower = u.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return null;
  }
  return u;
}

/// V1: full-page transcript + one fixed bottom audio player (no sync / scoring).
class ListeningPronunciationScreen extends ConsumerWidget {
  const ListeningPronunciationScreen({
    super.key,
    required this.contentId,
    this.storyTitle,
    this.audioUrl,
    this.lines,
    this.explanationLanguageOverride,
  });

  final String contentId;
  final String? storyTitle;
  final String? audioUrl;
  final List<ListeningTranscriptLine>? lines;

  /// When set (e.g. from route `extra`), skips SharedPreferences.
  final LearnExplanationLanguage? explanationLanguageOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final LearnExplanationLanguage lang = explanationLanguageOverride != null
        ? explanationLanguageOverride!
        : ref.watch(learnExplanationLanguageProvider);
    final showTranslation = ref.watch(monoReaderTranslationEnabledProvider);

    if (learnDemoMocksAllowed(contentId)) {
      final demoAudio = (audioUrl ?? '').trim().isNotEmpty
          ? audioUrl!.trim()
          : ListeningSampleData.defaultAudioUrl;
      final demoLines = lines ?? ListeningSampleData.mockLines;
      final sub = (storyTitle ?? '').trim();
      return _ListeningPlaybackView(
        key: ValueKey('demo:$demoAudio'),
        storySubtitle: sub,
        audioUrl: demoAudio,
        transcriptLines: demoLines,
        explanationLanguage: lang,
        showTranslation: showTranslation,
        audioUnavailableMessage: null,
        transcriptEmptyMessage: null,
      );
    }

    final detailAsync =
        ref.watch(catalogPublishedMonoDetailProvider(contentId));
    final snapAsync = ref.watch(learnPublishedSnapshotProvider(contentId));

    final pageBg = learnModuleListPageBackground(context);

    Widget wrapScaffold(Widget body) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: NimonBackButton(onPressed: () => context.pop()),
          titleSpacing: 0,
          title: Text(
            'Listening / Pronunciation',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: body,
      );
    }

    return detailAsync.when(
      loading: () => wrapScaffold(
        const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => wrapScaffold(
        _ListeningErrorBody(
          message: publishedMonoCatalogDetailErrorTitle(err),
          detail: publishedMonoCatalogDetailErrorBody(err),
          onRetry: () =>
              ref.invalidate(catalogPublishedMonoDetailProvider(contentId)),
        ),
      ),
      data: (detail) {
        return snapAsync.when(
          loading: () => wrapScaffold(
            const Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => wrapScaffold(
            _ListeningErrorBody(
              message: 'Could not load learning content.',
              detail: err.toString(),
              onRetry: () => ref.invalidate(
                catalogPublishedMonoDetailProvider(contentId),
              ),
            ),
          ),
          data: (snap) {
            final useLearn =
                shouldUsePublishedLearnSnapshot(detail.publishKind, snap);
            final dto = snap?.storyAudio;
            final httpUrl = useLearn ? publishedStoryAudioHttpUrl(dto) : null;

            var subtitle = (storyTitle ?? '').trim();
            if (subtitle.isEmpty) {
              subtitle = (dto?.displayName ?? '').trim();
            }
            final durSec = dto?.durationSeconds;
            if (durSec != null && durSec > 0) {
              final d = Duration(seconds: durSec);
              final m = d.inMinutes;
              final s = d.inSeconds.remainder(60);
              final durLabel = '$m:${s.toString().padLeft(2, '0')}';
              subtitle = subtitle.isEmpty ? durLabel : '$subtitle · $durLabel';
            }

            if (!useLearn) {
              return wrapScaffold(
                const _ListeningLockedBody(),
              );
            }

            if (httpUrl == null) {
              return wrapScaffold(
                const _ListeningAudioUnavailableBody(),
              );
            }

            final explicit = lines;
            final fromCore =
                listeningTranscriptLinesFromPublishedCore(detail.content);
            final catalogLines =
                (explicit != null && explicit.isNotEmpty) ? explicit : fromCore;
            final transcriptEmpty = catalogLines.isEmpty;

            return _ListeningPlaybackView(
              key: ValueKey('catalog:$httpUrl'),
              storySubtitle: subtitle,
              audioUrl: httpUrl,
              transcriptLines: catalogLines,
              explanationLanguage: lang,
              showTranslation: showTranslation,
              audioUnavailableMessage: null,
              transcriptEmptyMessage: transcriptEmpty
                  ? 'No transcript is published for this story yet.'
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ListeningLockedBody extends StatelessWidget {
  const _ListeningLockedBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Published listening practice isn’t available for this story yet. '
            'Stories published as read-only don’t include learning modules '
            'until you publish full learn.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Publish Full Learn from the creator workspace to sync story audio to readers.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningAudioUnavailableBody extends StatelessWidget {
  const _ListeningAudioUnavailableBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio is not available for this story yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Only streamed audio (http/https) can be played here. '
            'Local-only or missing URLs cannot be loaded in the catalog reader.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningErrorBody extends StatelessWidget {
  const _ListeningErrorBody({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Transcript + player; [audioUrl] null uses [audioUnavailableMessage] in the player card.
class _ListeningPlaybackView extends StatefulWidget {
  const _ListeningPlaybackView({
    super.key,
    required this.storySubtitle,
    required this.audioUrl,
    required this.transcriptLines,
    required this.explanationLanguage,
    required this.showTranslation,
    this.audioUnavailableMessage,
    this.transcriptEmptyMessage,
  });

  final String storySubtitle;
  final String? audioUrl;
  final List<ListeningTranscriptLine> transcriptLines;
  final LearnExplanationLanguage explanationLanguage;
  final bool showTranslation;

  final String? audioUnavailableMessage;
  final String? transcriptEmptyMessage;

  @override
  State<_ListeningPlaybackView> createState() => _ListeningPlaybackViewState();
}

class _ListeningPlaybackViewState extends State<_ListeningPlaybackView> {
  late final AudioPlayer _player;
  bool _audioReady = false;
  String? _loadError;
  static const List<double> _speedSteps = [0.75, 1.0, 1.25, 1.5];
  int _speedIndex = 1;

  double get _speed => _speedSteps[_speedIndex];

  bool get _hasPlayableUrl => (widget.audioUrl ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (_hasPlayableUrl) {
      unawaited(_initAudio());
    }
  }

  Future<void> _initAudio() async {
    final url = widget.audioUrl!.trim();
    try {
      await _player.setUrl(url);
      await _player.setSpeed(_speed);
      if (mounted) setState(() => _audioReady = true);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not load audio. Check connection.');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedSteps.length;
    });
    unawaited(_player.setSpeed(_speed));
  }

  bool _repeatOne = false;

  void _toggleRepeat() {
    setState(() => _repeatOne = !_repeatOne);
    unawaited(
      _player.setLoopMode(_repeatOne ? LoopMode.one : LoopMode.off),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pageBg = learnModuleListPageBackground(context);
    final subtitle = widget.storySubtitle.trim();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const cardReserve = 160.0;
    final lines = widget.transcriptLines;
    final showTranscriptEmpty = lines.isEmpty &&
        (widget.transcriptEmptyMessage ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: NimonBackButton(onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Listening / Pronunciation',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: showTranscriptEmpty
                ? ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      bottomInset + 16 + cardReserve,
                    ),
                    children: [
                      Text(
                        widget.transcriptEmptyMessage!.trim(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      bottomInset + 16 + cardReserve,
                    ),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: index == lines.length - 1 ? 0 : 22),
                        child: ListeningTranscriptSentenceBlock(
                          line: lines[index],
                          explanationLanguage: widget.explanationLanguage,
                          showTranslation: widget.showTranslation,
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
            child: _ListeningFloatingPlayerCard(
              player: _player,
              ready: _hasPlayableUrl ? _audioReady : true,
              loadError: _hasPlayableUrl
                  ? _loadError
                  : (widget.audioUnavailableMessage?.trim().isNotEmpty == true
                      ? widget.audioUnavailableMessage
                      : 'Audio is not available for this story yet.'),
              speed: _speed,
              repeatOne: _repeatOne,
              onCycleSpeed: _hasPlayableUrl ? _cycleSpeed : () {},
              onToggleRepeat: _hasPlayableUrl ? _toggleRepeat : () {},
              formatDuration: _fmt,
              controlsEnabled:
                  _hasPlayableUrl && _audioReady && _loadError == null,
            ),
          ),
        ],
      ),
    );
  }
}

/// One transcript block: Japanese, optional reading, one meaning line only.
class ListeningTranscriptSentenceBlock extends StatelessWidget {
  const ListeningTranscriptSentenceBlock({
    super.key,
    required this.line,
    required this.explanationLanguage,
    required this.showTranslation,
  });

  final ListeningTranscriptLine line;
  final LearnExplanationLanguage explanationLanguage;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = (line.reading ?? '').trim();
    final rubies = line.rubyTokens;
    final lineStyle = resolveNimonFuriganaLineStyle(
      context,
      theme,
      NimonFuriganaPreviewContext.reading,
    );

    final Widget japaneseBlock;
    if (rubies != null && rubies.isNotEmpty) {
      japaneseBlock = NimonRubyText(
        tokens: [
          for (final t in rubies)
            NimonRubyToken(text: t.text, reading: t.reading),
        ],
        baseStyle: lineStyle.baseStyle.copyWith(
          color: learnCreatorModulePrimaryTextColor(context),
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
        rubyStyle: lineStyle.rubyStyle,
      );
    } else {
      japaneseBlock = Text(
        line.japanese.trim(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: learnCreatorModulePrimaryTextColor(context),
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      );
    }

    final legacyMeaning = pickSupportText(
      explanationLanguage,
      en: line.meaningEn,
      my: line.meaningMy,
    );
    final pubDisplay = line.publishedExplanation != null
        ? monoLineExplanationDisplay(line.publishedExplanation)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        japaneseBlock,
        if (rubies == null || rubies.isEmpty)
          if (r.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: learnCreatorModuleSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        if (showTranslation) ...[
          if (pubDisplay != null && !pubDisplay.isEmpty) ...[
            const SizedBox(height: 10),
            _ListeningExplanationLines(display: pubDisplay),
          ] else if (legacyMeaning != null) ...[
            const SizedBox(height: 10),
            Text(
              legacyMeaning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: learnCreatorModuleSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ListeningExplanationLines extends StatelessWidget {
  const _ListeningExplanationLines({
    required this.display,
  });

  final MonoLineExplanationDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sec = display.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NimonTranslationText(text: display.primary),
        if (sec != null && sec.trim().isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              sec.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ListeningFloatingPlayerCard extends StatelessWidget {
  const _ListeningFloatingPlayerCard({
    required this.player,
    required this.ready,
    required this.loadError,
    required this.speed,
    required this.repeatOne,
    required this.onCycleSpeed,
    required this.onToggleRepeat,
    required this.formatDuration,
    this.controlsEnabled = true,
  });

  final AudioPlayer player;
  final bool ready;
  final String? loadError;
  final double speed;
  final bool repeatOne;
  final VoidCallback onCycleSpeed;
  final VoidCallback onToggleRepeat;
  final String Function(Duration) formatDuration;
  final bool controlsEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: learnCreatorModuleCardSurfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: learnCreatorModuleCardBorderColor(context)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: loadError != null && loadError!.trim().isNotEmpty
          ? Text(
              loadError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : !ready
              ? Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading audio…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StreamBuilder<Duration?>(
                          stream: player.durationStream,
                          builder: (context, durSnap) {
                            final duration = durSnap.data ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: player.positionStream,
                              builder: (context, posSnap) {
                                final position = posSnap.data ?? Duration.zero;
                                final totalMs = duration.inMilliseconds;
                                final posMs = position.inMilliseconds
                                    .clamp(0, totalMs > 0 ? totalMs : 0);
                                final maxVal =
                                    totalMs > 0 ? totalMs.toDouble() : 1.0;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDuration(position),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          formatDuration(duration),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape:
                                            SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        value: posMs.toDouble().clamp(
                                              0,
                                              maxVal,
                                            ),
                                        max: maxVal,
                                        onChanged: controlsEnabled &&
                                                totalMs > 0
                                            ? (v) {
                                                unawaited(
                                                  player.seek(
                                                    Duration(
                                                      milliseconds: v.round(),
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    cs.onSurface.withValues(alpha: 0.08),
                                foregroundColor: cs.onSurface,
                              ),
                              onPressed: controlsEnabled
                                  ? () {
                                      if (playing) {
                                        unawaited(player.pause());
                                      } else {
                                        unawaited(player.play());
                                      }
                                    }
                                  : null,
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: controlsEnabled ? onCycleSpeed : null,
                              child: Text(
                                '${speed}x',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color:
                                      learnCreatorModuleActionForegroundColor(
                                    context,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Repeat one',
                              style: IconButton.styleFrom(
                                foregroundColor: repeatOne
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                backgroundColor: repeatOne
                                    ? cs.onSurface.withValues(alpha: 0.08)
                                    : null,
                              ),
                              onPressed:
                                  controlsEnabled ? onToggleRepeat : null,
                              icon: const Icon(
                                Icons.repeat_one_rounded,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
