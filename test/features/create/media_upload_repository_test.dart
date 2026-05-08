import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';

void main() {
  group('MediaUploadRepository', () {
    test('uploadCover uses endpoint, Bearer header, and parses response',
        () async {
      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"url":"http://localhost:3000/uploads/u/cover/x.png",'
          '"mediaType":"image/png","originalName":"a.png","sizeBytes":10,"durationSeconds":null}',
          200,
        );
      });

      final repo = MediaUploadRepository(
        apiBaseUrl: 'http://localhost:3000/',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer zz'},
      );

      final file = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'a.png',
        mimeType: 'image/png',
      );
      final out = await repo.uploadCover(file);

      expect(captured, isNotNull);
      final req = captured!;
      expect(req.url.toString(), 'http://localhost:3000/v1/media/upload/cover');
      expect(req.headers['Authorization'], 'Bearer zz');
      expect(out.url, contains('/uploads/'));
      expect(out.mediaType, 'image/png');
      expect(out.originalName, 'a.png');
      expect(out.sizeBytes, 10);
      expect(out.durationSeconds, isNull);
    });

    test('415 maps to friendly message', () async {
      final client = MockClient(
        (_) async => http.Response('Unsupported type', 415),
      );
      final repo = MediaUploadRepository(
        apiBaseUrl: 'http://127.0.0.1:3000',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer z'},
      );
      final file = XFile.fromData(Uint8List(4), name: 'x.bin');
      await expectLater(
        repo.uploadCover(file),
        throwsA(
          predicate<Object>((e) {
            if (e is! MediaUploadException) return false;
            return e.userMessage.contains('not supported');
          }),
        ),
      );
    });

    test('413 maps to friendly message', () async {
      final client = MockClient(
        (_) async => http.Response('too big', 413),
      );
      final repo = MediaUploadRepository(
        apiBaseUrl: 'http://127.0.0.1:3000',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer z'},
      );
      final file = XFile.fromData(Uint8List(4), name: 'x.bin');
      await expectLater(
        repo.uploadCover(file),
        throwsA(
          predicate<Object>((e) {
            if (e is! MediaUploadException) return false;
            return e.userMessage.contains('too large');
          }),
        ),
      );
    });

    test('missing auth throws sign-in message', () async {
      final repo = MediaUploadRepository(
        apiBaseUrl: 'http://localhost:3000',
        client: MockClient((_) async => http.Response('{}', 200)),
        authHeaderBuilder: () async => <String, String>{},
      );
      final file = XFile.fromData(Uint8List(1), name: 'a.png');
      await expectLater(
        repo.uploadCover(file),
        throwsA(
          predicate<Object>((e) {
            if (e is! MediaUploadException) return false;
            return e.userMessage.contains('Sign in');
          }),
        ),
      );
    });
  });
}
