import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';

void main() {
  group('NimonImportMeta.fromJsonMap', () {
    test('parses generator metadata with human-readable labels', () {
      final meta = NimonImportMeta.fromJsonMap({
        'schemaVersion': 1,
        'generatorVersion': 'CSV_Generator_FullLearn_V7',
        'learningLanguage': 'Japanese',
        'contentCommunity': 'Burmese',
        'promptDataTab': 'AI_mode',
        'publishKind': 'full_learn_v1',
        'createdForEmail': 'User@Example.com',
      });

      expect(meta.schemaVersion, 1);
      expect(meta.generatorVersion, 'CSV_Generator_FullLearn_V7');
      expect(meta.learningLanguage, NimonLearningLanguage.japanese);
      expect(meta.contentCommunity, NimonContentCommunity.burmese);
      expect(meta.contentCommunity.contentLocaleWireCode, 'my');
      expect(meta.promptDataTab, NimonPromptDataTab.aiMode);
      expect(meta.importKind, NimonImportKind.fullLearn);
      expect(meta.createdForEmail, 'user@example.com');
      expect(meta.hasRecognizedImportKind, isTrue);
    });

    test('read_only_v1 publish kind maps to readOnly', () {
      final meta = NimonImportMeta.fromJsonMap({
        'publishKind': 'read_only_v1',
        'learningLanguage': 'Japanese',
        'contentCommunity': 'International / English',
      });
      expect(meta.importKind, NimonImportKind.readOnly);
      expect(meta.importKind.wirePublishKind, 'read_only_v1');
      expect(meta.contentCommunity, NimonContentCommunity.english);
      expect(meta.contentCommunity.contentLocaleWireCode, 'en');
    });
  });

  group('enum parsing helpers', () {
    test('rejects unknown learning language token', () {
      expect(
        nimonLearningLanguageFromString('Korean'),
        NimonLearningLanguage.unknown,
      );
    });

    test('english is parsed but not app-supported yet', () {
      expect(
        nimonLearningLanguageFromString('English'),
        NimonLearningLanguage.english,
      );
      expect(
        nimonLearningLanguageFromString('English').preferencesWireCode,
        'en',
      );
    });
  });

  group('NimonImportRawPayload.fromJsonMap', () {
    test('extracts meta, core, learn without trusting CreatorStoryV1', () {
      final payload = NimonImportRawPayload.fromJsonMap({
        'nimonImportMeta': {
          'schemaVersion': 1,
          'publishKind': 'read_only_v1',
          'learningLanguage': 'Japanese',
          'contentCommunity': 'Japanese',
          'createdForEmail': 'a@b.com',
        },
        'core': {'title': 'T'},
        'learn': {'vocabularyKanji': []},
        'sourceDraftId': 'gen-1',
      });

      expect(payload.hasMeta, isTrue);
      expect(payload.hasCoreSection, isTrue);
      expect(payload.hasLearnSection, isTrue);
      expect(payload.sourceDraftId, 'gen-1');
      expect(payload.meta?.importKind, NimonImportKind.readOnly);
      expect(payload.rawJson.containsKey('nimonImportMeta'), isTrue);
    });
  });

  group('NimonImportValidationResult', () {
    test('importPreviewOnly separates canImport from canPublishImmediately', () {
      const audioReq = NimonImportIssue(
        code: 'audio_required',
        message: 'Upload story audio before publishing Full Learn.',
        path: 'learn.audio',
        severity: NimonImportIssueSeverity.warning,
      );

      final r = NimonImportValidationResult.importPreviewOnly(
        missingPublishRequirements: [audioReq],
      );

      expect(r.canImport, isTrue);
      expect(r.canPublishImmediately, isFalse);
      expect(r.readyToPreviewOnly, isTrue);
      expect(r.hasMissingPublishRequirements, isTrue);
      expect(r.blockingErrors, isEmpty);
    });

    test('blocked sets both flags false', () {
      final r = NimonImportValidationResult.blocked([
        const NimonImportIssue(
          code: 'learning_language_unsupported',
          message: 'English learning is not available yet.',
        ),
      ]);
      expect(r.canImport, isFalse);
      expect(r.canPublishImmediately, isFalse);
    });

    test('importAndPublishReady sets both flags true', () {
      final r = NimonImportValidationResult.importAndPublishReady();
      expect(r.canImport, isTrue);
      expect(r.canPublishImmediately, isTrue);
      expect(r.readyToPreviewOnly, isFalse);
    });
  });
}
