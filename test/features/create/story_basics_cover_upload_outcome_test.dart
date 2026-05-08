import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/story_basics_cover_upload_outcome.dart';

void main() {
  group('coverUploadFailureInlineHint', () {
    test('null for sign-in / session copy (snackbar only)', () {
      expect(
        coverUploadFailureInlineHint(
          MediaUploadException('Sign in to upload media.'),
        ),
        isNull,
      );
      expect(
        coverUploadFailureInlineHint(
          MediaUploadException(
            'Session expired. Please sign in again.',
            statusCode: 401,
          ),
        ),
        isNull,
      );
    });

    test('network-style messages use short retry copy', () {
      final hint = coverUploadFailureInlineHint(
        MediaUploadException(
          'Could not reach the server. Check your connection and API base URL.',
        ),
      );
      expect(hint, equals('Upload failed. Try again.'));
    });

    test('413 / 415 map to size/type hints', () {
      expect(
        coverUploadFailureInlineHint(
          MediaUploadException('too large', statusCode: 413),
        ),
        contains('large'),
      );
      expect(
        coverUploadFailureInlineHint(
          MediaUploadException('unsupported', statusCode: 415),
        ),
        contains('supported'),
      );
    });
  });
}
