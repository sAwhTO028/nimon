import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

/// Layout metrics for one inline ruby token — must stay in sync with [_RenderInlineRubyToken.performLayout].
@immutable
class NimonInlineRubyLayoutMetrics {
  const NimonInlineRubyLayoutMetrics({
    required this.size,
    required this.alphabeticBaselineFromTop,
    required this.rubyAscent,
    required this.rubyPaintScale,
  });

  final Size size;
  final double alphabeticBaselineFromTop;
  final double rubyAscent;
  final double rubyPaintScale;

  PlaceholderDimensions toPlaceholderDimensions() {
    return PlaceholderDimensions(
      size: size,
      alignment: ui.PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      baselineOffset: alphabeticBaselineFromTop,
    );
  }
}

NimonInlineRubyLayoutMetrics _inlineRubyLayoutAfterPaintersLaidOut({
  required TextPainter basePainter,
  required TextPainter rubyPainter,
  required TextStyle baseStyle,
}) {
  final baseW = basePainter.width;
  final rubyW = rubyPainter.width;
  final rubyPaintScale =
      (rubyW <= 0 || baseW <= 0) ? 1.0 : math.min(1.0, baseW / rubyW);

  final baseFont = baseStyle.fontSize ?? 16.0;
  final rubyAscent =
      (rubyPainter.height * 0.86).clamp(6.0, baseFont * 0.85).toDouble();
  final alphabeticBaselineFromTop = rubyAscent +
      basePainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

  return NimonInlineRubyLayoutMetrics(
    size: Size(baseW, rubyAscent + basePainter.height),
    alphabeticBaselineFromTop: alphabeticBaselineFromTop,
    rubyAscent: rubyAscent,
    rubyPaintScale: rubyPaintScale,
  );
}

/// Computes placeholder size and baseline for one ruby token (used by measurement and [_RenderInlineRubyToken]).
NimonInlineRubyLayoutMetrics computeNimonInlineRubyLayoutMetrics({
  required String baseText,
  required String reading,
  required TextStyle baseStyle,
  required TextStyle rubyStyle,
  required TextDirection textDirection,
  double maxWidth = 10000.0,
}) {
  final basePainter = TextPainter(
    text: TextSpan(text: baseText, style: baseStyle),
    textDirection: textDirection,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);

  final rubyPainter = TextPainter(
    text: TextSpan(text: reading, style: rubyStyle),
    textDirection: textDirection,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);

  return _inlineRubyLayoutAfterPaintersLaidOut(
    basePainter: basePainter,
    rubyPainter: rubyPainter,
    baseStyle: baseStyle,
  );
}

/// Full layout metrics for a [NimonRubyText] paragraph, using the same spans and
/// [TextPainter.setPlaceholderDimensions] contract as on-screen [RichText].
@immutable
class NimonRubyTextMeasureResult {
  const NimonRubyTextMeasureResult({
    required this.height,
    required this.lineCount,
  });

  final double height;
  final int lineCount;
}

/// Measures [NimonRubyText] height and line count for pagination (render-aware).
NimonRubyTextMeasureResult measureNimonRubyText({
  required List<NimonRubyToken> tokens,
  required TextStyle baseStyle,
  required TextStyle rubyStyle,
  required double maxWidth,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  if (tokens.isEmpty) {
    return const NimonRubyTextMeasureResult(height: 0, lineCount: 0);
  }
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return const NimonRubyTextMeasureResult(height: 0, lineCount: 0);
  }

  final spans = <InlineSpan>[];
  final placeholderDims = <PlaceholderDimensions>[];

  for (final t in tokens) {
    final reading = (t.reading ?? '').trim();
    if (reading.isEmpty) {
      spans.add(TextSpan(text: t.text, style: baseStyle));
    } else {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: const SizedBox.shrink(),
        ),
      );
      placeholderDims.add(
        computeNimonInlineRubyLayoutMetrics(
          baseText: t.text,
          reading: reading,
          baseStyle: baseStyle,
          rubyStyle: rubyStyle,
          textDirection: textDirection,
          maxWidth: maxWidth,
        ).toPlaceholderDimensions(),
      );
    }
  }

  final tp = TextPainter(
    text: TextSpan(children: spans),
    textAlign: TextAlign.start,
    textDirection: textDirection,
    textScaler: textScaler,
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
  )..setPlaceholderDimensions(placeholderDims);

  tp.layout(maxWidth: maxWidth);
  final lines = tp.computeLineMetrics();
  return NimonRubyTextMeasureResult(
    height: tp.height,
    lineCount: lines.length,
  );
}

/// Generic ruby token for learner reading.
///
/// - If [reading] is null/empty, the token renders as normal Japanese text.
/// - If [reading] is present, furigana is painted above the base token inline.
class NimonRubyToken {
  final String text;
  final String? reading;

  const NimonRubyToken({
    required this.text,
    this.reading,
  });
}

/// Inline ruby renderer intended for long Japanese reading.
///
/// Uses a RenderObject-backed WidgetSpan to keep sentence flow natural while
/// painting compact ruby above the base glyphs.
///
/// For base/ruby [TextStyle]s, prefer [resolveNimonFuriganaLineStyle] with
/// [NimonFuriganaPreviewContext.reading] so hierarchy matches [NimonFuriganaPreviewTokens].
class NimonRubyText extends StatelessWidget {
  final List<NimonRubyToken> tokens;
  final TextStyle? baseStyle;
  final TextStyle? rubyStyle;
  final TextAlign textAlign;
  final Color? rubyColor;

  const NimonRubyText({
    super.key,
    required this.tokens,
    this.baseStyle,
    this.rubyStyle,
    this.textAlign = TextAlign.start,
    this.rubyColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final type = theme.type;

    final base = baseStyle ?? type.readingJa(theme, wc);
    final ruby = (rubyStyle ?? type.furigana(theme, wc)).copyWith(
      color: rubyColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.78),
    );

    final spans = <InlineSpan>[];
    for (final t in tokens) {
      final reading = (t.reading ?? '').trim();
      if (reading.isEmpty) {
        spans.add(TextSpan(text: t.text, style: base));
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineRubyToken(
              baseText: t.text,
              reading: reading,
              baseStyle: base,
              rubyStyle: ruby,
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign,
      softWrap: true,
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }
}

class _InlineRubyToken extends LeafRenderObjectWidget {
  const _InlineRubyToken({
    required this.baseText,
    required this.reading,
    required this.baseStyle,
    required this.rubyStyle,
  });

  final String baseText;
  final String reading;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInlineRubyToken(
      baseText: baseText,
      reading: reading,
      baseStyle: baseStyle,
      rubyStyle: rubyStyle,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderInlineRubyToken renderObject,
  ) {
    renderObject
      ..baseText = baseText
      ..reading = reading
      ..baseStyle = baseStyle
      ..rubyStyle = rubyStyle
      ..textDirection = Directionality.of(context);
  }
}

class _RenderInlineRubyToken extends RenderBox {
  _RenderInlineRubyToken({
    required String baseText,
    required String reading,
    required TextStyle baseStyle,
    required TextStyle rubyStyle,
    required TextDirection textDirection,
  })  : _baseText = baseText,
        _reading = reading,
        _baseStyle = baseStyle,
        _rubyStyle = rubyStyle,
        _textDirection = textDirection;

  final TextPainter _basePainter = TextPainter();
  final TextPainter _rubyPainter = TextPainter();

  String _baseText;
  set baseText(String v) {
    if (v == _baseText) return;
    _baseText = v;
    markNeedsLayout();
  }

  String _reading;
  set reading(String v) {
    if (v == _reading) return;
    _reading = v;
    markNeedsLayout();
  }

  TextStyle _baseStyle;
  set baseStyle(TextStyle v) {
    if (v == _baseStyle) return;
    _baseStyle = v;
    markNeedsLayout();
  }

  TextStyle _rubyStyle;
  set rubyStyle(TextStyle v) {
    if (v == _rubyStyle) return;
    _rubyStyle = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  double _alphabeticBaseline = 0;
  double _rubyAscent = 0;
  double _rubyPaintScale = 1.0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (baseline == TextBaseline.alphabetic) return _alphabeticBaseline;
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    _basePainter
      ..text = TextSpan(text: _baseText, style: _baseStyle)
      ..textDirection = _textDirection
      ..maxLines = 1;
    _rubyPainter
      ..text = TextSpan(text: _reading, style: _rubyStyle)
      ..textDirection = _textDirection
      ..maxLines = 1;

    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 10000.0;
    _basePainter.layout(maxWidth: maxW);
    _rubyPainter.layout(maxWidth: maxW);

    final m = _inlineRubyLayoutAfterPaintersLaidOut(
      basePainter: _basePainter,
      rubyPainter: _rubyPainter,
      baseStyle: _baseStyle,
    );
    _rubyPaintScale = m.rubyPaintScale;
    _rubyAscent = m.rubyAscent;

    size = constraints.constrain(m.size);
    _alphabeticBaseline = m.alphabeticBaselineFromTop;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    _basePainter.paint(canvas, Offset(offset.dx, offset.dy + _rubyAscent));

    final rubyW = _rubyPainter.width;
    if (_rubyPaintScale >= 0.999) {
      final rubyDx = offset.dx + (size.width - rubyW) / 2;
      final rubyDy = offset.dy + (_rubyAscent - _rubyPainter.height);
      _rubyPainter.paint(canvas, Offset(rubyDx, rubyDy));
      return;
    }

    final scaledW = rubyW * _rubyPaintScale;
    final rubyDx = offset.dx + (size.width - scaledW) / 2;
    final rubyDy = offset.dy + (_rubyAscent - _rubyPainter.height) / 2;
    canvas.save();
    canvas.translate(rubyDx, rubyDy);
    canvas.scale(_rubyPaintScale, _rubyPaintScale);
    _rubyPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}
