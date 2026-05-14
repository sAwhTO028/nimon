import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_refresh_401_coordinator.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/authenticated_http.dart';

import '../../auth/in_memory_auth_token_store.dart';

void main() {
  group('nimonUriShouldSkip401RefreshRetry', () {
    test('skips v1 auth login/register/refresh/logout', () {
      final base = Uri.parse('http://localhost:3000');
      expect(
        nimonUriShouldSkip401RefreshRetry(base.replace(path: '/v1/auth/login')),
        isTrue,
      );
      expect(
        nimonUriShouldSkip401RefreshRetry(
          base.replace(path: '/v1/auth/register'),
        ),
        isTrue,
      );
      expect(
        nimonUriShouldSkip401RefreshRetry(
          base.replace(path: '/v1/auth/refresh'),
        ),
        isTrue,
      );
      expect(
        nimonUriShouldSkip401RefreshRetry(
          base.replace(path: '/v1/auth/logout'),
        ),
        isTrue,
      );
      expect(
        nimonUriShouldSkip401RefreshRetry(
          base.replace(path: '/v1/me/preferences'),
        ),
        isFalse,
      );
    });
  });

  group('AuthRefresh401Coordinator + AuthenticatedHttp', () {
    test(
        'expired access: 401 then refresh then retry succeeds; rotated refresh stored',
        () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/v1/auth/refresh') {
          refreshCalls++;
          return http.Response(
            jsonEncode({
              'accessToken': 'newAccess',
              'refreshToken': 'newRefresh',
              'tokenType': 'Bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'email': 'a@b.c'},
              'profile': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/protected') {
          final auth = request.headers['authorization'] ?? '';
          if (auth.contains('oldAccess')) {
            return http.Response('{}', 401);
          }
          if (auth.contains('newAccess')) {
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('{}', 401);
        }
        fail('unexpected ${request.url}');
      });

      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'oldAccess', refreshToken: 'rt1'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);

      final uri = Uri.parse('http://localhost:9/v1/protected');
      final resp = await send(
        requestUri: uri,
        mergeHeaders: () async => {
          'Authorization': 'Bearer ${(await store.readTokens())!.accessToken}',
          'Accept': 'application/json',
        },
        send: (h) => client.get(uri, headers: h),
      );

      expect(resp.statusCode, 200);
      expect(refreshCalls, 1);
      final t = await store.readTokens();
      expect(t?.accessToken, 'newAccess');
      expect(t?.refreshToken, 'newRefresh');
      expect(notifier.state, isA<AuthSessionAuthenticated>());
    });

    test('concurrent 401: single refresh, both retries succeed', () async {
      var refreshCalls = 0;
      var protectedHits = 0;
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/v1/auth/refresh') {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({
              'accessToken': 'acc2',
              'refreshToken': 'ref2',
              'tokenType': 'Bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'email': 'a@b.c'},
              'profile': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/a' || p == '/v1/b') {
          protectedHits++;
          final auth = request.headers['authorization'] ?? '';
          if (auth.contains('old')) {
            return http.Response('{}', 401);
          }
          return http.Response('ok', 200);
        }
        fail('unexpected ${request.url}');
      });

      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'old', refreshToken: 'r'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);

      final ua = Uri.parse('http://localhost:9/v1/a');
      final ub = Uri.parse('http://localhost:9/v1/b');
      Future<http.Response> one(Uri u) => send(
            requestUri: u,
            mergeHeaders: () async => {
              'Authorization':
                  'Bearer ${(await store.readTokens())!.accessToken}',
            },
            send: (h) => client.get(u, headers: h),
          );

      final r = await Future.wait([one(ua), one(ub)]);
      expect(r[0].statusCode, 200);
      expect(r[1].statusCode, 200);
      expect(refreshCalls, 1);
      expect(protectedHits, greaterThanOrEqualTo(4));
    });

    test('refresh failure: clears session', () async {
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/v1/auth/refresh') {
          return http.Response('{}', 401);
        }
        if (p == '/v1/protected') {
          return http.Response('{}', 401);
        }
        fail('unexpected ${request.url}');
      });
      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      notifier.state = const AuthSessionAuthenticated(
        AuthUser(id: 'u1', email: 'e', displayName: null, handle: null),
      );
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
      final uri = Uri.parse('http://localhost:9/v1/protected');
      final resp = await send(
        requestUri: uri,
        mergeHeaders: () async => {
          'Authorization': 'Bearer ${(await store.readTokens())!.accessToken}',
        },
        send: (h) => client.get(uri, headers: h),
      );
      expect(resp.statusCode, 401);
      expect(await store.readTokens(), isNull);
      expect(notifier.state, isA<AuthSessionUnauthenticated>());
    });

    test('no refresh token: no refresh HTTP, session cleared', () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/refresh') {
          refreshCalls++;
        }
        return http.Response('{}', 401);
      });
      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
          const StoredAuthTokens(accessToken: 'a', refreshToken: ''));
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      notifier.state = const AuthSessionAuthenticated(
        AuthUser(id: 'u1', email: 'e', displayName: null, handle: null),
      );
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
      final uri = Uri.parse('http://localhost:9/v1/x');
      await send(
        requestUri: uri,
        mergeHeaders: () async => {'Authorization': 'Bearer a'},
        send: (h) => client.get(uri, headers: h),
      );
      expect(refreshCalls, 0);
      expect(await store.readTokens(), isNull);
    });

    test('retried request 401: no second refresh (refresh count 1)', () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/v1/auth/refresh') {
          refreshCalls++;
          return http.Response(
            jsonEncode({
              'accessToken': 'n',
              'refreshToken': 'nr',
              'tokenType': 'Bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'email': 'a@b.c'},
              'profile': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/protected') {
          return http.Response('{}', 401);
        }
        fail('unexpected ${request.url}');
      });
      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'o', refreshToken: 'rt'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
      final uri = Uri.parse('http://localhost:9/v1/protected');
      final resp = await send(
        requestUri: uri,
        mergeHeaders: () async => {
          'Authorization': 'Bearer ${(await store.readTokens())!.accessToken}',
        },
        send: (h) => client.get(uri, headers: h),
      );
      expect(resp.statusCode, 401);
      expect(refreshCalls, 1);
    });

    test(
        'restoreSession with expired access refreshes and persists rotated refresh',
        () async {
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/v1/me') {
          final auth = request.headers['authorization'] ?? '';
          if (auth.contains('expired')) {
            return http.Response('{}', 401);
          }
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'email': 'a@b.c'},
              'profile': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (p == '/v1/auth/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'fresh',
              'refreshToken': 'rotated',
              'tokenType': 'Bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('unexpected ${request.url}');
      });
      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'expired', refreshToken: 'rt0'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      await notifier.restoreSession();
      final t = await store.readTokens();
      expect(t?.refreshToken, 'rotated');
      expect(t?.accessToken, 'fresh');
      expect(notifier.state, isA<AuthSessionAuthenticated>());
    });
  });

  group('AuthenticatedHttp without coordinator (guest)', () {
    test('401 without Bearer skips refresh attempt', () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/refresh') {
          refreshCalls++;
        }
        return http.Response('{}', 401);
      });
      final store = InMemoryAuthTokenStore();
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
      final uri = Uri.parse('http://localhost:9/v1/mono/feed');
      final resp = await send(
        requestUri: uri,
        mergeHeaders: () async =>
            <String, String>{'Accept': 'application/json'},
        send: (h) => client.get(uri, headers: h),
      );
      expect(resp.statusCode, 401);
      expect(refreshCalls, 0);
    });

    test('401 on v1/auth/login is not refresh-retried even with Bearer',
        () async {
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/refresh') {
          refreshCalls++;
          return http.Response(
            jsonEncode({
              'accessToken': 'x',
              'refreshToken': 'y',
              'tokenType': 'Bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 401);
      });
      final store = InMemoryAuthTokenStore();
      await store.writeTokens(
        const StoredAuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      final repo = AuthRepository(
        apiBaseUrl: 'http://localhost:9',
        httpClient: client,
      );
      final notifier = AuthSessionNotifier(repo, store);
      final coordinator = AuthRefresh401Coordinator(
        authRepository: repo,
        tokenStore: store,
        sessionNotifier: notifier,
      );
      final send = nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
      final uri = Uri.parse('http://localhost:9/v1/auth/login');
      final resp = await send(
        requestUri: uri,
        mergeHeaders: () async => {
          'Authorization': 'Bearer ${(await store.readTokens())!.accessToken}',
        },
        send: (h) => client.post(uri, headers: h),
      );
      expect(resp.statusCode, 401);
      expect(refreshCalls, 0);
    });
  });
}
