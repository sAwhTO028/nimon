import 'package:flutter/material.dart';
import 'package:nimon/features/create/story_creator_furigana_tokens.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/ui/reading/nimon_furigana_preview_style.dart';

/// Optional typography overrides while keeping the same wrap + ruby layout rules.
/// Merged on top of [resolveNimonFuriganaLineStyle] for the given [previewContext].
@immutable
class NimonJapaneseSentenceStyle {
  const NimonJapaneseSentenceStyle({
    this.baseTextStyle,
    this.rubyTextStyle,
  });

  final TextStyle? baseTextStyle;
  final TextStyle? rubyTextStyle;
}

/// Shared Japanese sentence line: plain script tokens and optional per-span ruby,
/// using a [Wrap] of atomic units for stable wrapping on narrow screens.
///
/// Used by Storytelling cards, modals, and Semantics/Vocabulary when sentence-level
/// Japanese is shown. Card chrome stays in the caller; only text rendering lives here.
///
/// Furigana hierarchy and spacing come from [NimonFuriganaPreviewTokens] via
/// [resolveNimonFuriganaLineStyle] — use [previewContext] to pick the app variant.
class NimonJapaneseSentenceLine extends StatelessWidget {
  const NimonJapaneseSentenceLine({
    super.key,
    required this.text,
    required this.spans,
    required this.theme,
    this.style,
    this.previewContext = NimonFuriganaPreviewContext.storytelling,
  });

  final String text;
  final List<FuriganaSpan> spans;
  final ThemeData theme;

  /// When non-null, merged onto the resolved [NimonFuriganaLineStyle] for this context.
  final NimonJapaneseSentenceStyle? style;

  /// Creator vs details share metrics; [NimonFuriganaPreviewContext.reading] uses
  /// [NimonTypography] reading scale for long-form UI.
  final NimonFuriganaPreviewContext previewContext;

  @override
  Widget build(BuildContext context) {
    var line = resolveNimonFuriganaLineStyle(context, theme, previewContext);
    if (style?.baseTextStyle != null) {
      line = NimonFuriganaLineStyle(
        baseStyle: line.baseStyle.merge(style!.baseTextStyle!),
        rubyStyle: line.rubyStyle,
        wrapSpacing: line.wrapSpacing,
        wrapRunSpacing: line.wrapRunSpacing,
        rubyBaseGap: line.rubyBaseGap,
      );
    }
    if (style?.rubyTextStyle != null) {
      line = NimonFuriganaLineStyle(
        baseStyle: line.baseStyle,
        rubyStyle: line.rubyStyle.merge(style!.rubyTextStyle!),
        wrapSpacing: line.wrapSpacing,
        wrapRunSpacing: line.wrapRunSpacing,
        rubyBaseGap: line.rubyBaseGap,
      );
    }

    final baseStyle = line.baseStyle;
    final rubyStyle = line.rubyStyle;

    try {
      final children = _buildWrapChildren(
        text: text,
        spans: spans,
        baseStyle: baseStyle,
        rubyStyle: rubyStyle,
        rubyBaseGap: line.rubyBaseGap,
      );
      if (children.length == 1 && children.first is Text) {
        return RepaintBoundary(child: children.first);
      }
      return RepaintBoundary(
        child: Wrap(
          spacing: line.wrapSpacing,
          runSpacing: line.wrapRunSpacing,
          crossAxisAlignment: WrapCrossAlignment.end,
          alignment: WrapAlignment.start,
          children: children,
        ),
      );
    } catch (_) {
      return RepaintBoundary(
        child: Text(
          text,
          softWrap: true,
          style: baseStyle,
        ),
      );
    }
  }
}

List<Widget> _buildWrapChildren({
  required String text,
  required List<FuriganaSpan> spans,
  required TextStyle baseStyle,
  required TextStyle rubyStyle,
  required double rubyBaseGap,
}) {
  if (text.isEmpty) {
    return [const SizedBox.shrink()];
  }

  final sorted = spans.where((s) {
    if (!s.isValid) return false;
    if (s.start < 0 || s.end > text.length || s.end <= s.start) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  final hasRuby = sorted.any((s) => s.reading.trim().isNotEmpty);
  if (!hasRuby) {
    return [
      Text(
        text,
        softWrap: true,
        style: baseStyle,
      ),
    ];
  }

  final out = <Widget>[];
  var pos = 0;

  void addPlainRange(int start, int end) {
    if (end <= start) return;
    final slice = text.substring(start, end);
    if (slice.isEmpty) return;
    final toks = splitStoryTextIntoFuriganaTokens(slice);
    if (toks.isEmpty) {
      out.add(
        Text(
          slice,
          softWrap: true,
          style: baseStyle,
          key: ValueKey<String>('plain-$start-$end'),
        ),
      );
      return;
    }
    for (final t in toks) {
      final absStart = start + t.start;
      out.add(
        Text(
          t.text,
          softWrap: true,
          style: baseStyle,
          key: ValueKey<String>('plain-$absStart-${t.end + start}'),
        ),
      );
    }
  }

  for (final s in sorted) {
    final start = s.start;
    final end = s.end;
    if (end <= pos) continue;
    if (start < pos) continue;

    if (start > pos) {
      addPlainRange(pos, start);
    }

    final reading = s.reading.trim();

    if (reading.isEmpty) {
      addPlainRange(start, end);
    } else {
      final baseSlice = text.substring(start, end);
      out.add(
        _NimonRubyUnit(
          key: ValueKey<String>('ruby-$start-$end'),
          base: baseSlice,
          reading: reading,
          baseStyle: baseStyle,
          rubyStyle: rubyStyle,
          rubyBaseGap: rubyBaseGap,
        ),
      );
    }
    pos = end;
  }

  if (pos < text.length) {
    addPlainRange(pos, text.length);
  }

  if (out.isEmpty) {
    return [
      Text(
        text,
        softWrap: true,
        style: baseStyle,
      ),
    ];
  }
  return out;
}

class _NimonRubyUnit extends StatelessWidget {
  const _NimonRubyUnit({
    super.key,
    required this.base,
    required this.reading,
    required this.baseStyle,
    required this.rubyStyle,
    required this.rubyBaseGap,
  });

  final String base;
  final String reading;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;
  final double rubyBaseGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          reading,
          style: rubyStyle,
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: rubyBaseGap),
        Text(
          base,
          style: baseStyle,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 3,
          overflow: TextOverflow.fade,
        ),
      ],
    );
  }
}
