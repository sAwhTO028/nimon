import 'package:nimon/features/mono/mono_content_model.dart';

/// Visible explanation strings for a Mono sentence line (localized meanings).
///
/// [sourceLine] is preferred primary (maps from [LocalizedMeanings.my] / source language).
/// [englishLine] is optional secondary ([LocalizedMeanings.en]).
class MonoLineExplanationDisplay {
  const MonoLineExplanationDisplay({
    required this.primary,
    this.secondary,
  });

  final String primary;

  /// When both source and English exist, show below [primary] with muted styling.
  final String? secondary;

  bool get isEmpty =>
      primary.trim().isEmpty &&
      (secondary == null || secondary!.trim().isEmpty);
}

/// Picks story translation lines from [MonoExplanationLine] without exposing raw JSON.
///
/// Prefer **source** ([MonoExplanationLine.my]) as primary, then English.
MonoLineExplanationDisplay? monoLineExplanationDisplay(MonoExplanationLine? e) {
  if (e == null) return null;
  final en = (e.en ?? '').trim();
  final my = (e.my ?? '').trim();
  if (my.isEmpty && en.isEmpty) return null;
  if (my.isNotEmpty && en.isNotEmpty && my != en) {
    return MonoLineExplanationDisplay(primary: my, secondary: en);
  }
  if (my.isNotEmpty) {
    return MonoLineExplanationDisplay(primary: my);
  }
  return MonoLineExplanationDisplay(primary: en);
}
