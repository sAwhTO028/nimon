import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/import/nimon_hidden_json_import_flow.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';

void main() {
  group('decodeImportJsonRoot', () {
    test('parses object root', () {
      final m = decodeImportJsonRoot('{"a": 1}');
      expect(m['a'], 1);
    });

    test('rejects array root', () {
      expect(
        () => decodeImportJsonRoot('[1]'),
        throwsA(isA<NimonImportJsonParseException>()),
      );
    });

    test('rejects invalid JSON', () {
      expect(
        () => decodeImportJsonRoot('{bad'),
        throwsA(isA<NimonImportJsonParseException>()),
      );
    });
  });

  group('importSuccessDialogBody', () {
    test('preview only when no missing requirements', () {
      final body = importSuccessDialogBody(
        NimonImportValidationResult.importAndPublishReady(),
      );
      expect(body, 'This draft is ready to preview.');
      expect(body, isNot(contains('Audio upload')));
    });

    test('mentions audio when full learn audio required', () {
      final body = importSuccessDialogBody(
        NimonImportValidationResult.importPreviewOnly(
          missingPublishRequirements: const [
            NimonImportIssue(
              code: 'import.fullLearn.audioRequired',
              message: 'Audio upload is required before Full Learn publish.',
            ),
          ],
        ),
      );
      expect(body, contains('ready to preview'));
      expect(body, contains('Audio upload'));
    });
  });

  group('importedDraftPreviewLocation', () {
    test('builds canonical sentences route with encoded draftId', () {
      expect(
        importedDraftPreviewLocation('draft-abc'),
        '/create/story/sentences?draftId=draft-abc',
      );
    });

    test('encodes special characters in draftId', () {
      final loc = importedDraftPreviewLocation('id with spaces');
      expect(Uri.parse(loc).queryParameters['draftId'], 'id with spaces');
    });
  });
}
