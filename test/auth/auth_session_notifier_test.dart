import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_auth_token_store.dart';

void main() {
  test('login persists tokens and sets authenticated user', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'acc',
            'refreshToken': 'ref',
            'tokenType': 'Bearer',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/me') {
        return http.Response(
          jsonEncode({
            'user': {'id': 'uid', 'email': 'x@y.com'},
            'profile': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      fail('unexpected ${request.url}');
    });

    final store = InMemoryAuthTokenStore();
    final repo = AuthRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      httpClient: client,
    );
    final notifier = AuthSessionNotifier(repo, store);

    await notifier.login(email: 'x@y.com', password: 'pw');

    expect(notifier.state, isA<AuthSessionAuthenticated>());
    final u = (notifier.state as AuthSessionAuthenticated).user;
    expect(u.id, 'uid');
    final stored = await store.readTokens();
    expect(stored?.accessToken, 'acc');
    expect(stored?.refreshToken, 'ref');
  });

  test('logout clears tokens', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/logout') {
        expect(request.url.path, '/v1/auth/logout');
        return http.Response('', 204);
      }
      fail('unexpected ${request.url}');
    });

    final store = InMemoryAuthTokenStore();
    await store.writeTokens(
      const StoredAuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    final repo = AuthRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      httpClient: client,
    );
    final notifier = AuthSessionNotifier(repo, store);

    await notifier.logout();

    expect(await store.readTokens(), isNull);
    expect(notifier.state, isA<AuthSessionUnauthenticated>());
  });

  test('forceSessionExpired clears tokens without logout HTTP', () async {
    final client = MockClient((request) async {
      fail('unexpected HTTP ${request.url}');
    });

    final store = InMemoryAuthTokenStore();
    await store.writeTokens(
      const StoredAuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    final notifier = AuthSessionNotifier(
      AuthRepository(apiBaseUrl: 'http://127.0.0.1:9', httpClient: client),
      store,
    );

    await notifier.forceSessionExpired();

    expect(await store.readTokens(), isNull);
    expect(notifier.state, isA<AuthSessionUnauthenticated>());
  });
}
