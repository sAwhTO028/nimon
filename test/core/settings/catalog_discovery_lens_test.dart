import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';

void main() {
  group('CatalogDiscoveryLens', () {
    test('tryFromPreferences builds en+my lens', () {
      const prefs = UserPreferences(
        appLocale: 'system',
        contentLocale: 'my',
        learningLanguage: 'en',
        themeMode: 'system',
        readingTextSize: 'standard',
        showExplanations: true,
      );
      final lens = CatalogDiscoveryLens.tryFromPreferences(prefs);
      expect(lens?.contentLocale, 'my');
      expect(lens?.learningLanguage, 'en');
      expect(lens!.toQueryParameters(), {
        'contentLocale': 'my',
        'learningLanguage': 'en',
      });
    });

    test('tryFromPreferences returns null for same-language pair', () {
      const prefs = UserPreferences(
        appLocale: 'system',
        contentLocale: 'ja',
        learningLanguage: 'ja',
        themeMode: 'system',
        readingTextSize: 'standard',
        showExplanations: true,
      );
      expect(CatalogDiscoveryLens.tryFromPreferences(prefs), isNull);
    });

    test('mergeIntoQueryIfAuthenticated skips guest without Authorization', () {
      final qp = <String, String>{'limit': '15'};
      CatalogDiscoveryLens.mergeIntoQueryIfAuthenticated(
        qp,
        const CatalogDiscoveryLens(contentLocale: 'my', learningLanguage: 'en'),
        <String, String>{'Accept': 'application/json'},
      );
      expect(qp.containsKey('learningLanguage'), isFalse);
    });

    test('mergeIntoQueryIfAuthenticated adds params when Bearer present', () {
      final qp = <String, String>{};
      CatalogDiscoveryLens.mergeIntoQueryIfAuthenticated(
        qp,
        const CatalogDiscoveryLens(contentLocale: 'my', learningLanguage: 'ja'),
        {'Authorization': 'Bearer x', 'Accept': 'application/json'},
      );
      expect(qp['contentLocale'], 'my');
      expect(qp['learningLanguage'], 'ja');
    });
  });
}
