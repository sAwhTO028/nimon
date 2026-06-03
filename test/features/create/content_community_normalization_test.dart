import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/features/create/import/nimon_import_payload.dart';
import 'package:nimon/features/create/import/nimon_import_validator.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';

const _email = 'user@example.com';

NimonImportValidationContext _ctx(String contentLocaleCode) =>
    NimonImportValidationContext(
      learningLanguageCode: 'ja',
      contentLocaleCode: contentLocaleCode,
      authenticatedEmail: _email,
    );

Map<String, Object?> _metaJson({String contentCommunity = 'Myanmar'}) => {
      'schemaVersion': 1,
      'learningLanguage': 'Japanese',
      'contentCommunity': contentCommunity,
      'promptDataTab': 'AI_mode',
      'createdForEmail': _email,
      'publishKind': 'read_only_v1',
    };

Map<String, Object?> _minimalPayload({String contentCommunity = 'Myanmar'}) {
  return {
    'nimonImportMeta': _metaJson(contentCommunity: contentCommunity),
    'storyCore': {
      'title': 'T',
      'category': 'Daily Life',
      'level': 'N5',
      'description': 'd',
      'targetDurationBandKey': '3_5',
      'sentences': [
        {
          'order': 1,
          'content': {
            'japaneseText': 'あいうえおかきくけこ',
            'meanings': {'en': 'x', 'my': 'x', 'byLanguage': <String, Object?>{}},
            'furiganaSpans': <Object>[],
          },
        },
      ],
    },
  };
}

void main() {
  group('normalizeContentCommunity', () {
    test('aliases map to canonical labels', () {
      expect(normalizeContentCommunityLabel('Myanmar'), 'Myanmar');
      expect(normalizeContentCommunityLabel('Burmese'), 'Myanmar');
      expect(normalizeContentCommunityLabel('my'), 'Myanmar');
      expect(
        normalizeContentCommunityLabel('International / English'),
        'International / English',
      );
      expect(
        normalizeContentCommunityLabel('International English'),
        'International / English',
      );
      expect(normalizeContentCommunityLabel('English'), 'International / English');
      expect(normalizeContentCommunityLabel('en'), 'International / English');
      expect(normalizeContentCommunityLabel('Japanese'), 'Japanese');
      expect(normalizeContentCommunityLabel('ja'), 'Japanese');
    });

    test('wire code normalization migrates legacy stored values', () {
      expect(normalizeContentLocaleWireCode('Burmese'), 'my');
      expect(normalizeContentLocaleWireCode('Myanmar'), 'my');
      expect(normalizeContentLocaleWireCode('my'), 'my');
      expect(normalizeContentLocaleWireCode('en'), 'en');
      expect(normalizeContentLocaleWireCode(null), isNull);
    });

    test('display label uses migrated wire code', () {
      expect(contentCommunityDisplayLabel('Burmese'), 'Myanmar');
      expect(contentCommunityDisplayLabel('my'), 'Myanmar');
      expect(contentCommunityDisplayLabel('en'), 'International / English');
    });
  });

  group('import contentCommunity context', () {
    test('A default en wire + Myanmar JSON passes after normalization', () {
      final prefs = UserPreferences.defaults.copyWith(contentLocale: 'my');
      final wire = normalizeContentLocaleWireCode(prefs.contentLocale)!;
      final payload = NimonImportRawPayload.fromJsonMap(
        _minimalPayload(contentCommunity: 'Myanmar'),
      );
      final result = validateNimonImportPayload(payload, _ctx(wire));
      expect(
        result.blockingErrors.map((i) => i.code),
        isNot(contains('import.context.contentCommunityMismatch')),
      );
    });

    test('legacy stored Burmese preference matches Myanmar JSON', () {
      final wire = normalizeContentLocaleWireCode('Burmese');
      expect(wire, 'my');
      final payload = NimonImportRawPayload.fromJsonMap(
        _minimalPayload(contentCommunity: 'Myanmar'),
      );
      final result = validateNimonImportPayload(payload, _ctx(wire!));
      expect(
        result.blockingErrors.map((i) => i.code),
        isNot(contains('import.context.contentCommunityMismatch')),
      );
    });

    test('B JSON Burmese alias + setting Myanmar passes', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        _minimalPayload(contentCommunity: 'Burmese'),
      );
      final result = validateNimonImportPayload(payload, _ctx('my'));
      expect(
        result.blockingErrors.map((i) => i.code),
        isNot(contains('import.context.contentCommunityMismatch')),
      );
    });

    test('B JSON Japanese + setting Myanmar blocks', () {
      final payload = NimonImportRawPayload.fromJsonMap(
        _minimalPayload(contentCommunity: 'Japanese'),
      );
      final result = validateNimonImportPayload(payload, _ctx('my'));
      expect(
        result.blockingErrors.map((i) => i.code),
        contains('import.context.contentCommunityMismatch'),
      );
    });

    test('preference en wire does not match Myanmar JSON', () {
      expect(
        contentCommunityMatchesPreference(
          preferenceContentLocale: 'en',
          importContentCommunityRaw: 'Myanmar',
        ),
        isFalse,
      );
      expect(
        contentCommunityMatchesPreference(
          preferenceContentLocale: 'my',
          importContentCommunityRaw: 'Myanmar',
        ),
        isTrue,
      );
    });
  });
}
