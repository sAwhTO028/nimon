import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listDraftIds attaches Authorization Bearer header', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'items': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemoteStoryDraftRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      fallbackLocal: const LocalStoryDraftRepository(),
      authHeaderBuilder: () async => {'Authorization': 'Bearer test-token'},
    );

    await repo.listDraftIds();

    expect(captured!.headers['authorization'], 'Bearer test-token');
  });
}
