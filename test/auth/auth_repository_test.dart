import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login parses tokens and getMe returns user', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/login') {
        expect(request.headers['content-type'], contains('json'));
        return http.Response(
          jsonEncode({
            'accessToken': 'access-1',
            'refreshToken': 'refresh-1',
            'tokenType': 'Bearer',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/me') {
        expect(request.headers['authorization'], 'Bearer access-1');
        return http.Response(
          jsonEncode({
            'user': {'id': 'u-1', 'email': 'a@b.com'},
            'profile': {
              'displayName': 'A',
              'handle': 'a',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      fail('unexpected ${request.url}');
    });

    final repo = AuthRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      httpClient: client,
    );
    final tokens = await repo.login(email: 'a@b.com', password: 'secret');
    expect(tokens.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');

    final me = await repo.getMe(accessToken: tokens.accessToken);
    expect(me.id, 'u-1');
    expect(me.email, 'a@b.com');
    expect(me.displayName, 'A');
    expect(me.handle, 'a');
  });

  test('login maps ClientException to friendly connection message', () async {
    final client = MockClient((request) async {
      throw http.ClientException(
        'Failed to fetch',
        Uri.parse('http://127.0.0.1:9/v1/auth/login'),
      );
    });
    final repo = AuthRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      httpClient: client,
    );
    await expectLater(
      repo.login(email: 'a@b.com', password: 'secret12345'),
      throwsA(
        isA<AuthRepositoryException>().having(
          (e) => e.message,
          'message',
          'Cannot connect to server. Please check that the backend is running.',
        ),
      ),
    );
  });
}
