import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/config/nimon_api_config.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

void main() {
  test('login/register hit RemoteBackendConfig api origin when wired that way',
      () async {
    final base = RemoteBackendConfig.apiBaseUrl;
    expect(base, NimonApiConfig.apiBaseUrl);

    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      if (request.url.path == '/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'a',
            'refreshToken': 'r',
            'tokenType': 'Bearer',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/me') {
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1', 'email': 'a@b.com'},
            'profile': null,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/auth/register') {
        return http.Response(
          jsonEncode({
            'accessToken': 'a',
            'refreshToken': 'r',
            'tokenType': 'Bearer',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      fail('unexpected ${request.url}');
    });

    final repo = AuthRepository(
      apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
      httpClient: client,
    );

    await repo.login(email: 'a@b.com', password: 'password12345');
    final loginUri = seen.firstWhere((u) => u.path == '/v1/auth/login');
    expect(loginUri.scheme, Uri.parse(base).scheme);
    expect(loginUri.host, Uri.parse(base).host);

    seen.clear();
    await repo.register(email: 'c@d.com', password: 'password12345');
    final regUri = seen.firstWhere((u) => u.path == '/v1/auth/register');
    expect(regUri.scheme, Uri.parse(base).scheme);
    expect(regUri.host, Uri.parse(base).host);
  });

  /// Run with:
  /// `flutter test test/features/auth/auth_repository_remote_config_origin_test.dart --dart-define=VERIFY_NIMON_API_DEFINE=true --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com`
  test(
    'login targets global test host when NIMON_API_BASE_URL is set at compile time',
    () async {
      final base = RemoteBackendConfig.apiBaseUrl;
      expect(base, 'https://nimon-api-global-test.onrender.com');

      final client = MockClient((request) async {
        expect(request.url.host, 'nimon-api-global-test.onrender.com');
        expect(request.url.path, '/v1/auth/login');
        return http.Response(
          jsonEncode({
            'accessToken': 'a',
            'refreshToken': 'r',
            'tokenType': 'Bearer',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final repo = AuthRepository(
        apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
        httpClient: client,
      );
      await repo.login(email: 'a@b.com', password: 'password12345');
    },
    skip: const bool.fromEnvironment('VERIFY_NIMON_API_DEFINE',
            defaultValue: false)
        ? false
        : 'Enable with --dart-define=VERIFY_NIMON_API_DEFINE=true and '
            '--dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com',
  );
}
