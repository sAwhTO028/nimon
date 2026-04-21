import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Body size: tuned for dense Japanese reading on phones (compact but legible).
double monoReadingBodyFontSize(double logicalWidth) {
  if (logicalWidth < 360) return 20;
  if (logicalWidth < 400) return 21.5;
  if (logicalWidth < 430) return 23;
  return 24.5;
}

/// Default line height multiplier for Mono plain-text pagination (not too airy).
const double monoReadingLineHeightFactor = 1.44;

/// Target ~28–36 full-width glyphs per line; hard cap ~40. Returns max width for the text block.
///
/// [rightExtraGutter] reserves space for a right column (e.g. Mono Learn rail) without treating
/// that column as full-width bottom padding.
double monoReadingTextMaxWidth({
  required double layoutWidth,
  required double horizontalPadding,
  required double fontSize,
  double rightExtraGutter = 0,
}) {
  const targetChars = 32.0;
  const maxChars = 40.0;
  final glyphAdvance = fontSize * 1.02;
  final byTarget = targetChars * glyphAdvance;
  final byMax = maxChars * glyphAdvance;
  final inner =
      layoutWidth - horizontalPadding - horizontalPadding - rightExtraGutter;
  return math
      .min(inner, math.min(byTarget, byMax))
      .clamp(160.0, double.infinity);
}

/// Exposed for post-layout overflow safety checks.
double measureMonoReadingHeight(
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler textScaler,
) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
    maxLines: null,
  )..layout(maxWidth: maxWidth);
  return tp.height;
}

/// Natural clause / sentence boundaries (not fixed sentence counts).
List<String> _segmentJapaneseText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return [];

  final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
  final out = <String>[];

  for (final raw in paragraphs) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    var start = 0;
    for (var i = 0; i < p.length; i++) {
      final ch = p[i];
      if (ch == '。' || ch == '！' || ch == '？' || ch == '．') {
        out.add(p.substring(start, i + 1));
        start = i + 1;
      }
    }
    if (start < p.length) {
      out.add(p.substring(start));
    }
  }

  return out.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
}

List<String> _splitOversizedSegment(
  String segment,
  TextStyle style,
  double maxWidth,
  double maxHeight,
  TextScaler textScaler,
) {
  final result = <String>[];
  var remaining = segment.trimLeft();
  if (remaining.isEmpty) return result;

  while (remaining.isNotEmpty) {
    final chars = remaining.characters;
    var lo = 1;
    var hi = chars.length;
    var best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final sub = chars.take(mid).toString();
      final h = measureMonoReadingHeight(sub, style, maxWidth, textScaler);
      if (h <= maxHeight) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (best == 0) {
      best = 1;
    }
    final page = chars.take(best).toString().trim();
    if (page.isNotEmpty) result.add(page);
    remaining = chars.skip(best).toString().trimLeft();
  }

  return result.isEmpty ? [segment] : result;
}

/// Splits [text] into pages that fit [maxHeight] at [maxWidth], using measured layout only.
List<String> splitMonoReadingIntoPages({
  required String text,
  required TextStyle bodyStyle,
  required double maxWidth,
  required double maxHeight,
  required TextScaler textScaler,
}) {
  final t = text.trim();
  if (t.isEmpty) return [''];
  if (maxHeight <= 12 || maxWidth <= 12) return [t];

  final segments = _segmentJapaneseText(t);
  final units = segments.isEmpty ? <String>[t] : segments;

  final pages = <String>[];
  final buf = StringBuffer();

  void flushBuf() {
    if (buf.isEmpty) return;
    pages.add(buf.toString().trim());
    buf.clear();
  }

  for (final seg in units) {
    final s = seg.trim();
    if (s.isEmpty) continue;

    final candidate = buf.isEmpty ? s : '${buf.toString()}$s';
    final h =
        measureMonoReadingHeight(candidate, bodyStyle, maxWidth, textScaler);
    if (h <= maxHeight) {
      buf.write(s);
    } else {
      flushBuf();
      final hSeg = measureMonoReadingHeight(s, bodyStyle, maxWidth, textScaler);
      if (hSeg <= maxHeight) {
        buf.write(s);
      } else {
        pages.addAll(
          _splitOversizedSegment(s, bodyStyle, maxWidth, maxHeight, textScaler),
        );
      }
    }
  }
  flushBuf();

  return pages.isEmpty ? [''] : pages;
}

/// One internal reading "page" for the stepped layout: wide top region, narrow lower-left region.
class MonoSteppedReadingPage {
  final String topText;
  final String bottomText;

  const MonoSteppedReadingPage({
    required this.topText,
    required this.bottomText,
  });
}

int _fitCharsByHeight({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double maxHeight,
  required TextScaler textScaler,
}) {
  if (text.isEmpty) return 0;
  if (maxHeight <= 12 || maxWidth <= 12) return text.characters.length;

  final chars = text.characters;
  var lo = 1;
  var hi = chars.length;
  var best = 0;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final sub = chars.take(mid).toString();
    final h = measureMonoReadingHeight(sub, style, maxWidth, textScaler);
    if (h <= maxHeight) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best;
}

/// Splits [text] into internal pages that flow through two stacked regions:
///
/// - **Top region**: wide width ([topMaxWidth]) with height [topMaxHeight]
/// - **Bottom region**: narrower width ([bottomMaxWidth]) with height [bottomMaxHeight]
///
/// This approximates a stepped reading shape: the copy uses full width until it reaches the
/// lower-right blocked zone, then continues in a narrower left column.
List<MonoSteppedReadingPage> splitMonoReadingIntoSteppedPages({
  required String text,
  required TextStyle bodyStyle,
  required double topMaxWidth,
  required double topMaxHeight,
  required double bottomMaxWidth,
  required double bottomMaxHeight,
  required TextScaler textScaler,
}) {
  final t = text.trim();
  if (t.isEmpty) {
    return const [MonoSteppedReadingPage(topText: '', bottomText: '')];
  }

  // If the stepped geometry is degenerate, fall back to single-box paging.
  if (topMaxHeight <= 12 || topMaxWidth <= 12) {
    final pages = splitMonoReadingIntoPages(
      text: t,
      bodyStyle: bodyStyle,
      maxWidth: math.max(topMaxWidth, bottomMaxWidth),
      maxHeight: math.max(topMaxHeight, bottomMaxHeight),
      textScaler: textScaler,
    );
    return pages
        .map((p) => MonoSteppedReadingPage(topText: p, bottomText: ''))
        .toList(growable: false);
  }

  var remaining = t;
  final out = <MonoSteppedReadingPage>[];

  while (remaining.trim().isNotEmpty) {
    var topText = '';
    var bottomText = '';

    // 1) Fill the wide top region.
    final topFit = _fitCharsByHeight(
      text: remaining,
      style: bodyStyle,
      maxWidth: topMaxWidth,
      maxHeight: topMaxHeight,
      textScaler: textScaler,
    );
    if (topFit > 0) {
      topText = remaining.characters.take(topFit).toString().trimRight();
      remaining = remaining.characters.skip(topFit).toString().trimLeft();
    }

    // 2) Then fill the narrow lower-left region (if any).
    if (remaining.trim().isNotEmpty &&
        bottomMaxHeight > 12 &&
        bottomMaxWidth > 12) {
      final bottomFit = _fitCharsByHeight(
        text: remaining,
        style: bodyStyle,
        maxWidth: bottomMaxWidth,
        maxHeight: bottomMaxHeight,
        textScaler: textScaler,
      );
      if (bottomFit > 0) {
        bottomText =
            remaining.characters.take(bottomFit).toString().trimRight();
        remaining = remaining.characters.skip(bottomFit).toString().trimLeft();
      }
    }

    // Safety: ensure forward progress even if measurement returns 0.
    if (topText.isEmpty && bottomText.isEmpty) {
      final one = remaining.characters.take(1).toString();
      topText = one;
      remaining = remaining.characters.skip(1).toString().trimLeft();
    }

    out.add(MonoSteppedReadingPage(topText: topText, bottomText: bottomText));
  }

  return out.isEmpty
      ? const [MonoSteppedReadingPage(topText: '', bottomText: '')]
      : out;
}

/// Bounded memo for [splitMonoReadingIntoSteppedPages] when story id, body, layout, and scaler match.
final Map<int, List<MonoSteppedReadingPage>> _steppedSplitMemo = {};
const int _steppedSplitMemoMax = 32;

/// Same output as [splitMonoReadingIntoSteppedPages], reusing results when inputs are unchanged.
List<MonoSteppedReadingPage> splitMonoReadingIntoSteppedPagesMemo({
  required String cacheStoryId,
  required int bodyHash,
  required int layoutSig,
  required int scalerKey,
  required String text,
  required TextStyle bodyStyle,
  required double topMaxWidth,
  required double topMaxHeight,
  required double bottomMaxWidth,
  required double bottomMaxHeight,
  required TextScaler textScaler,
}) {
  final key = Object.hash(cacheStoryId, bodyHash, layoutSig, scalerKey);
  final hit = _steppedSplitMemo[key];
  if (hit != null) return hit;

  final pages = splitMonoReadingIntoSteppedPages(
    text: text,
    bodyStyle: bodyStyle,
    topMaxWidth: topMaxWidth,
    topMaxHeight: topMaxHeight,
    bottomMaxWidth: bottomMaxWidth,
    bottomMaxHeight: bottomMaxHeight,
    textScaler: textScaler,
  );
  _steppedSplitMemo[key] = pages;
  while (_steppedSplitMemo.length > _steppedSplitMemoMax) {
    _steppedSplitMemo.remove(_steppedSplitMemo.keys.first);
  }
  return pages;
}
