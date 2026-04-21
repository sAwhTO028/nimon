import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/learn/learn_support_text.dart';
import 'package:nimon/features/learn/listening_transcript_models.dart';
import 'package:nimon/features/settings/settings_providers.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1: full-page transcript + one fixed bottom audio player (no sync / scoring).
class ListeningPronunciationScreen extends ConsumerStatefulWidget {
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

  static const _bg = Color(0xFFF6F3EA);
  static const _ink = Color(0xFF1A1917);
  static const _inkMuted = Color(0xFF5C5A55);

  @override
  ConsumerState<ListeningPronunciationScreen> createState() =>
      _ListeningPronunciationScreenState();
}

class _ListeningPronunciationScreenState
    extends ConsumerState<ListeningPronunciationScreen> {
  late final AudioPlayer _player;
  bool _audioReady = false;
  String? _loadError;
  static const List<double> _speedSteps = [0.75, 1.0, 1.25, 1.5];
  int _speedIndex = 1;

  double get _speed => _speedSteps[_speedIndex];

  LearnExplanationLanguage get _explanationLanguage =>
      widget.explanationLanguageOverride ??
      ref.watch(learnExplanationLanguageProvider);

  List<ListeningTranscriptLine> get _lines =>
      widget.lines ?? ListeningSampleData.mockLines;

  String get _audioSource =>
      (widget.audioUrl ?? '').trim().isNotEmpty
          ? widget.audioUrl!.trim()
          : ListeningSampleData.defaultAudioUrl;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_initAudio());
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(_audioSource);
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
    final subtitle = (widget.storyTitle ?? '').trim();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showExplanation = ref.watch(monoExplanationEnabledSettingProvider);
    /// Space for floating card + margin so last transcript lines stay visible.
    const cardReserve = 160.0;

    return Scaffold(
      backgroundColor: ListeningPronunciationScreen._bg,
      appBar: AppBar(
        backgroundColor: ListeningPronunciationScreen._bg,
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
                color: ListeningPronunciationScreen._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ListeningPronunciationScreen._inkMuted,
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
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                bottomInset + 16 + cardReserve,
              ),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: index == _lines.length - 1 ? 0 : 22),
                  child: ListeningTranscriptSentenceBlock(
                    line: _lines[index],
                    explanationLanguage: _explanationLanguage,
                    showExplanation: showExplanation,
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
              ready: _audioReady,
              loadError: _loadError,
              speed: _speed,
              repeatOne: _repeatOne,
              onCycleSpeed: _cycleSpeed,
              onToggleRepeat: _toggleRepeat,
              formatDuration: _fmt,
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
    required this.showExplanation,
  });

  final ListeningTranscriptLine line;
  final LearnExplanationLanguage explanationLanguage;
  final bool showExplanation;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = (line.reading ?? '').trim();
    final meaning = showExplanation
        ? pickSupportText(
            explanationLanguage,
            en: line.meaningEn,
            my: line.meaningMy,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line.japanese.trim(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        if (r.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            r,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _muted,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
        if (meaning != null) ...[
          const SizedBox(height: 10),
          Text(
            meaning,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _muted,
              fontWeight: FontWeight.w500,
              height: 1.45,
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
  });

  final AudioPlayer player;
  final bool ready;
  final String? loadError;
  final double speed;
  final bool repeatOne;
  final VoidCallback onCycleSpeed;
  final VoidCallback onToggleRepeat;
  final String Function(Duration) formatDuration;

  static const _ink = Color(0xFF1A1917);
  static const _muted = Color(0xFF5C5A55);
  static const _cardBg = Color(0xFFFDFCF9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: loadError != null
            ? Text(
                loadError!,
                style: theme.textTheme.bodySmall?.copyWith(color: _muted),
              )
            : !ready
                ? Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _ink.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading audio…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted,
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
                                  final position =
                                      posSnap.data ?? Duration.zero;
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
                                              color: _muted,
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
                                              color: _muted,
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
                                          thumbShape:
                                              const RoundSliderThumbShape(
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
                                          onChanged: totalMs > 0
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
                                      _ink.withValues(alpha: 0.08),
                                  foregroundColor: _ink,
                                ),
                                onPressed: () {
                                  if (playing) {
                                    unawaited(player.pause());
                                  } else {
                                    unawaited(player.play());
                                  }
                                },
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: onCycleSpeed,
                                child: Text(
                                  '${speed}x',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: _ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Repeat one',
                                style: IconButton.styleFrom(
                                  foregroundColor: repeatOne
                                      ? _ink
                                      : _muted,
                                  backgroundColor: repeatOne
                                      ? _ink.withValues(alpha: 0.08)
                                      : null,
                                ),
                                onPressed: onToggleRepeat,
                                icon: Icon(
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
