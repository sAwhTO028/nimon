import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/login_screen.dart';
import 'package:nimon/features/auth/register_screen.dart';

import '../../auth/in_memory_auth_token_store.dart';

void main() {
  testWidgets('failed login does not navigate to /mono', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/login') {
        return http.Response('Unauthorized', 401);
      }
      return http.Response('Not found', 404);
    });

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('mono_home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(InMemoryAuthTokenStore()),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              apiBaseUrl: 'http://127.0.0.1:9',
              httpClient: client,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'a@b.com');
    await tester.enterText(fields.last, 'password12345');
    await tester.tap(find.widgetWithText(FilledButton, 'LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('mono_home'), findsNothing);
    expect(find.text('Great!'), findsOneWidget);
  });

  testWidgets('failed register does not navigate to /mono', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/register') {
        return http.Response('Conflict', 409);
      }
      return http.Response('Not found', 404);
    });

    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('mono_home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(InMemoryAuthTokenStore()),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              apiBaseUrl: 'http://127.0.0.1:9',
              httpClient: client,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'a@b.com');
    await tester.enterText(fields.at(1), 'password12345');
    await tester.enterText(fields.at(2), 'password12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('mono_home'), findsNothing);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets(
      'disposed LoginScreen does not setState after delayed login failure',
      (tester) async {
    final setStateAfterDispose = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      if (s.contains('setState() called after dispose')) {
        setStateAfterDispose.add(details);
      }
      previous?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = previous;
    });

    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/login') {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return http.Response('Unauthorized', 401);
      }
      return http.Response('Not found', 404);
    });

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('mono')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(InMemoryAuthTokenStore()),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              apiBaseUrl: 'http://127.0.0.1:9',
              httpClient: client,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'a@b.com');
    await tester.enterText(fields.last, 'password12345');
    await tester.tap(find.widgetWithText(FilledButton, 'LOGIN'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));

    expect(setStateAfterDispose, isEmpty);
  });

  testWidgets(
      'disposed RegisterScreen does not setState after delayed register failure',
      (tester) async {
    final setStateAfterDispose = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      if (s.contains('setState() called after dispose')) {
        setStateAfterDispose.add(details);
      }
      previous?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = previous;
    });

    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/register') {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return http.Response('Conflict', 409);
      }
      return http.Response('Not found', 404);
    });

    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('mono')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(InMemoryAuthTokenStore()),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(
              apiBaseUrl: 'http://127.0.0.1:9',
              httpClient: client,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'a@b.com');
    await tester.enterText(fields.at(1), 'password12345');
    await tester.enterText(fields.at(2), 'password12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));

    expect(setStateAfterDispose, isEmpty);
  });
}
