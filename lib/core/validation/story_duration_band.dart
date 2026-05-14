/// Mirrors backend [resolveStoryDurationBand]: explicit band wins; otherwise infer
/// from [durationSeconds] when present (creator manual duration).
/// Returns null → JLPT×band limits skipped (no blocking).
String? resolveStoryDurationBand({
  String? targetDurationBandKey,
  int? durationSeconds,
}) {
  final raw = targetDurationBandKey?.trim();
  if (raw == '3_5' || raw == '5_7' || raw == '7_9') return raw;

  if (durationSeconds == null || durationSeconds <= 0) return null;
  final minutes = durationSeconds / 60;
  if (minutes >= 3 && minutes < 5) return '3_5';
  if (minutes >= 5 && minutes < 7) return '5_7';
  if (minutes >= 7 && minutes <= 9) return '7_9';
  return null;
}

/// Maps creator level string to JLPT keys used by limit tables.
String? normalizeJlptLevel(String? levelRaw) {
  final s = (levelRaw ?? '').trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.contains('n1')) return 'N1';
  if (s.contains('n2')) return 'N2';
  if (s.contains('n3')) return 'N3';
  if (s.contains('n4')) return 'N4';
  if (s.contains('n5')) return 'N5';
  return null;
}
