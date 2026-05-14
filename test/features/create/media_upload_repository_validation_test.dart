import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('uploadCover parses validation_failed before generic 400', () async {
    final client = MockClient((req) async {
      if (req.url.path.contains('/v1/media/upload/cover')) {
        return http.Response(
          jsonEncode({
            'statusCode': 400,
            'message': 'validation_failed',
            'issues': [
              {
                'code': 'media.file.required',
                'field': 'media.file',
                'messageKey': 'media.file.required',
                'severity': 'blocking',
                'source': 'media-validation',
              },
            ],
          }),
          400,
        );
      }
      return http.Response('', 404);
    });

    final repo = MediaUploadRepository(
      apiBaseUrl: 'http://localhost:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    await expectLater(
      repo.uploadCover(
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'x.png',
          mimeType: 'image/png',
        ),
      ),
      throwsA(isA<HttpValidationFailedException>()),
    );
  });
}
