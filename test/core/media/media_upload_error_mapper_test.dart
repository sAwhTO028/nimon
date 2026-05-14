import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/media/media_upload_error_mapper.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';

void main() {
  group('mediaUploadUserMessage', () {
    test('HttpValidationFailedException uses fallback message for image type',
        () {
      final ex = HttpValidationFailedException([
        ValidationIssue(
          code: 'media.image.invalidType',
          field: 'coverImage',
          messageKey: 'media.image.invalidType',
          severity: ValidationSeverity.blocking,
          source: 'media-validation',
        ),
      ]);
      final msg = mediaUploadUserMessage(
        ex,
        surface: MediaUploadSurface.storyCover,
      );
      expect(msg, contains('JPG'));
    });

    test('HttpValidationFailedException maps audio too large key', () {
      final ex = HttpValidationFailedException([
        ValidationIssue(
          code: 'media.audio.tooLarge',
          field: 'audioFile',
          messageKey: 'media.audio.tooLarge',
          severity: ValidationSeverity.blocking,
          source: 'media-validation',
          params: {'maxBytes': 50000000},
        ),
      ]);
      expect(
        mediaUploadUserMessage(ex, surface: MediaUploadSurface.listeningAudio),
        contains('too large'),
      );
    });

    test('415-style MediaUploadException keeps friendly copy', () {
      expect(
        mediaUploadUserMessage(
          MediaUploadException(
            'This file type is not supported for upload.',
            statusCode: 415,
          ),
          surface: MediaUploadSurface.profileAvatar,
        ),
        contains('supported'),
      );
    });

    test('offline SocketException maps to network.offline copy', () {
      expect(
        mediaUploadUserMessage(
          SocketException('failed'),
          surface: MediaUploadSurface.storyCover,
        ),
        contains('internet'),
      );
    });

    test('generic fallback differs for audio surface', () {
      expect(
        mediaUploadUserMessage(
          Exception('x'),
          surface: MediaUploadSurface.listeningAudio,
        ),
        contains('audio'),
      );
    });
  });

  group('isMediaValidationError', () {
    test('true for HttpValidationFailedException', () {
      expect(
        isMediaValidationError(
          HttpValidationFailedException(const []),
        ),
        isTrue,
      );
    });

    test('false for MediaUploadException', () {
      expect(
        isMediaValidationError(MediaUploadException('x')),
        isFalse,
      );
    });
  });
}
