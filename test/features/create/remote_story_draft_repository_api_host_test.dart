import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';

void main() {
  test('listDraftIds GET uses injected apiBaseUrl origin', () async {
    final seen = <Uri>[];
    final client = http_testing.MockClient((req) async {
      seen.add(req.url);
      return http.Response(
        '{"items":[]}',
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    final repo = RemoteStoryDraftRepository(
      apiBaseUrl: 'https://nimon-api-global-test.onrender.com/',
      client: client,
      authHeaderBuilder: () async => const {},
    );

    await repo.listDraftIds();

    expect(seen, isNotEmpty);
    expect(seen.single.scheme, 'https');
    expect(seen.single.host, 'nimon-api-global-test.onrender.com');
    expect(seen.single.path, '/v1/story-drafts');
  });
}
