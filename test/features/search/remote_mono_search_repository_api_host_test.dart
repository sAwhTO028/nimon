import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:nimon/features/search/data/remote_mono_search_repository.dart';

void main() {
  test('searchMonos GET uses injected apiBaseUrl origin', () async {
    final seen = <Uri>[];
    final client = http_testing.MockClient((req) async {
      seen.add(req.url);
      return http.Response(
        '{"items":[],"hasMore":false,"totalCount":0}',
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    final repo = RemoteMonoSearchRepository(
      apiBaseUrl: 'https://nimon-api-global-test.onrender.com/',
      client: client,
      authHeaderBuilder: () async => const {},
    );

    await repo.searchMonos();

    expect(seen, isNotEmpty);
    expect(seen.single.scheme, 'https');
    expect(seen.single.host, 'nimon-api-global-test.onrender.com');
    expect(seen.single.path, '/v1/search/monos');
  });
}
