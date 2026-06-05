import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';

void main() {
  test('fetchBookmarkedPage maps learningLanguage and contentLocale', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'monoId': 'm1',
              'title': 'T',
              'level': 'N5',
              'contentLocale': 'my',
              'learningLanguage': 'en',
            },
          ],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSocialRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    final page = await repo.fetchBookmarkedPage(PageRequest(limit: 10));
    expect(page.items, hasLength(1));
    expect(page.items.single.contentLocale, 'my');
    expect(page.items.single.learningLanguage, 'en');
  });
}
