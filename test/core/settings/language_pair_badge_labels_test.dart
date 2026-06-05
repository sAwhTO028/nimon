import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/language_pair_badge_labels.dart';

void main() {
  test('languagePairBadgeShortLabel renders EN · MY', () {
    expect(
      languagePairBadgeShortLabel(
        learningLanguage: 'en',
        contentLocale: 'my',
      ),
      'EN · MY',
    );
  });

  test('languagePairBadgeShortLabel renders JA · EN', () {
    expect(
      languagePairBadgeShortLabel(
        learningLanguage: 'ja',
        contentLocale: 'en',
      ),
      'JA · EN',
    );
  });

  test('languagePairBadgeVisibleOnDiscoverySurfaces', () {
    expect(
      languagePairBadgeVisibleOnDiscoverySurfaces(
        learningLanguage: 'en',
        contentLocale: 'my',
      ),
      isTrue,
    );
    expect(
      languagePairBadgeVisibleOnDiscoverySurfaces(
        learningLanguage: null,
        contentLocale: null,
      ),
      isFalse,
    );
    expect(
      languagePairBadgeVisibleOnDiscoverySurfaces(
        learningLanguage: null,
        contentLocale: 'my',
      ),
      isTrue,
    );
  });

  test('null legacy segments use em dash placeholders', () {
    expect(
      languagePairBadgeShortLabel(
        learningLanguage: null,
        contentLocale: 'my',
      ),
      '— · MY',
    );
    expect(
      languagePairBadgeShortLabel(
        learningLanguage: 'en',
        contentLocale: null,
      ),
      'EN · —',
    );
    expect(
      languagePairBadgeShortLabel(
        learningLanguage: null,
        contentLocale: null,
      ),
      '—',
    );
  });
}
