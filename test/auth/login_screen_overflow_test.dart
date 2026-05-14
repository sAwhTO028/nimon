import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/login_screen.dart';

import 'in_memory_auth_token_store.dart';

void main() {
  testWidgets(
    'login: keyboard inset + failed login shows error without RenderFlex overflow',
    (WidgetTester tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final overflowReports = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final s = details.exceptionAsString();
        if (s.contains('overflowed') || s.contains('OVERFLOW')) {
          overflowReports.add(details);
        }
        previousOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = previousOnError;
      });

      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/login') {
          return http.Response('', 401);
        }
        return http.Response('', 404);
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
          GoRoute(
            path: '/register',
            builder: (_, __) => const Scaffold(body: Text('reg')),
          ),
        ],
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(() {
        tester.view.viewInsets = FakeViewPadding.zero;
      });

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

      expect(find.text('Great!'), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.first, 'a@b.com');
      await tester.enterText(fields.last, 'secret');
      final loginButton = find.widgetWithText(FilledButton, 'LOGIN');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(overflowReports, isEmpty);
      expect(find.widgetWithText(FilledButton, 'LOGIN'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    },
  );
}
