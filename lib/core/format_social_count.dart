/// Compact display for social metrics (likes, followers, etc.). English-only; no i18n.
///
/// Rules:
/// - `0` … `999` → decimal string (`"0"`, `"1"`, `"999"`).
/// - `1_000` … `9_999` → one decimal when needed (`"1K"`, `"1.2K"`, `"9.9K"`).
/// - `10_000` … `999_999` → whole thousands (`"12K"`).
/// - `>= 1_000_000` → `"1.2M"` / `"12M"` style.
String formatSocialCount(int n) {
  var v = n;
  if (v < 0) v = 0;
  if (v < 1000) return '$v';
  if (v < 10000) {
    final thousands = v / 1000;
    final s = thousands.toStringAsFixed(1);
    if (s.endsWith('.0')) {
      return '${s.substring(0, s.length - 2)}K';
    }
    return '${s}K';
  }
  if (v < 1000000) {
    final k = (v / 1000).round();
    return '${k}K';
  }
  final millions = v / 1000000;
  if (millions < 10) {
    final s = millions.toStringAsFixed(1);
    if (s.endsWith('.0')) {
      return '${s.substring(0, s.length - 2)}M';
    }
    return '${s}M';
  }
  return '${millions.round()}M';
}

/// Under the React control on Mono: avoid showing a noisy `"0"` in the narrow rail;
/// show a compact abbreviated count only when there is at least one like.
String monoReactRailPrimaryLabel(int likesCount) {
  if (likesCount <= 0) return 'React';
  return formatSocialCount(likesCount);
}

/// Accessibility label always mentions React and includes the numeric context.
String monoReactRailSemanticsLabel(int likesCount) {
  if (likesCount <= 0) return 'React';
  return 'React, ${formatSocialCount(likesCount)} likes';
}
