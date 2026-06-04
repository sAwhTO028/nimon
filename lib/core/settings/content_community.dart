// Canonical Content Community values (Settings + import JSON).

/// Wire codes stored in [UserPreferences.contentLocale] (`en` | `my` | `ja`).
abstract final class ContentCommunityWire {
  ContentCommunityWire._();

  static const myanmar = 'my';
  static const internationalEnglish = 'en';
  static const japanese = 'ja';
}

/// Human-facing canonical labels (import JSON `contentCommunity` field).
abstract final class ContentCommunityLabel {
  ContentCommunityLabel._();

  static const myanmar = 'Myanmar';
  static const internationalEnglish = 'International / English';
  static const japanese = 'Japanese';
}

String _normalizeToken(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '';
  return t
      .toLowerCase()
      .replaceAll('/', '_')
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// Canonical display label for import JSON / logs, or `null` when unrecognized.
String? normalizeContentCommunityLabel(String? value) {
  final k = _normalizeToken(value);
  if (k.isEmpty) return null;
  if (k == 'myanmar' || k == 'burmese' || k == 'my') {
    return ContentCommunityLabel.myanmar;
  }
  if (k == 'english' ||
      k == 'en' ||
      k == 'international' ||
      k == 'international_english' ||
      (k.contains('international') && k.contains('english'))) {
    return ContentCommunityLabel.internationalEnglish;
  }
  if (k == 'japanese' || k == 'ja' || k == 'jp') {
    return ContentCommunityLabel.japanese;
  }
  return null;
}

/// Normalizes stored settings wire codes and legacy aliases to `en` | `my` | `ja`.
String? normalizeContentLocaleWireCode(String? value) {
  final label = normalizeContentCommunityLabel(value);
  return switch (label) {
    ContentCommunityLabel.myanmar => ContentCommunityWire.myanmar,
    ContentCommunityLabel.internationalEnglish =>
      ContentCommunityWire.internationalEnglish,
    ContentCommunityLabel.japanese => ContentCommunityWire.japanese,
    _ => null,
  };
}

/// Settings subtitle for a (possibly legacy) stored [UserPreferences.contentLocale].
String contentCommunityDisplayLabel(String? storedValue) {
  final wire =
      normalizeContentLocaleWireCode(storedValue) ?? ContentCommunityWire.internationalEnglish;
  return switch (wire) {
    ContentCommunityWire.myanmar => ContentCommunityLabel.myanmar,
    ContentCommunityWire.japanese => ContentCommunityLabel.japanese,
    _ => ContentCommunityLabel.internationalEnglish,
  };
}

/// Compact list-row badge label for owner surfaces (M22F-1): `MY`, `EN`, `JA`, or `—`.
String contentCommunityBadgeShortLabel(String? contentLocale) {
  final wire = normalizeContentLocaleWireCode(contentLocale);
  return switch (wire) {
    ContentCommunityWire.myanmar => 'MY',
    ContentCommunityWire.internationalEnglish => 'EN',
    ContentCommunityWire.japanese => 'JA',
    _ => '—',
  };
}

/// Accessibility / tooltip label for [contentCommunityBadgeShortLabel].
String contentCommunityBadgeSemanticsLabel(String? contentLocale) {
  final short = contentCommunityBadgeShortLabel(contentLocale);
  if (short == '—') return 'Community unset';
  return contentCommunityDisplayLabel(contentLocale);
}

/// Collection card badge: `MIX` for legacy/null collection community (M22F-2).
String contentCommunityCollectionBadgeShortLabel(String? contentLocale) {
  final wire = normalizeContentLocaleWireCode(contentLocale);
  if (wire == null) return 'MIX';
  return contentCommunityBadgeShortLabel(contentLocale);
}

/// Semantics for collection list badges.
String contentCommunityCollectionBadgeSemanticsLabel(String? contentLocale) {
  final wire = normalizeContentLocaleWireCode(contentLocale);
  if (wire == null) return 'Legacy or mixed community';
  return contentCommunityDisplayLabel(contentLocale);
}

/// Returns `true` when import JSON community matches the user's settings wire code.
bool contentCommunityMatchesPreference({
  required String? preferenceContentLocale,
  required String? importContentCommunityRaw,
}) {
  final expected =
      normalizeContentLocaleWireCode(preferenceContentLocale) ??
          ContentCommunityWire.internationalEnglish;
  final importLabel = normalizeContentCommunityLabel(importContentCommunityRaw);
  if (importLabel == null) return false;
  final importWire = normalizeContentLocaleWireCode(importLabel);
  return importWire != null && importWire == expected;
}
