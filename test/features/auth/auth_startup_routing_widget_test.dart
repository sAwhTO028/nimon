import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_startup_routing.dart';

import '../../support/auth_session_test_overrides.dart';

void main() {
  testWidgets('M17L: authenticated + /startup redirects to /mono',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/startup',
      redirect: nimonAuthRedirect,
      routes: [
        GoRoute(
          path: '/startup',
          builder: (_, __) => const Scaffold(body: Text('splash')),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('home_mono')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login_page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authenticatedAuthSessionOverride],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/mono');
    expect(find.text('home_mono'), findsOneWidget);
    expect(find.text('login_page'), findsNothing);
  });

  testWidgets('M17L: guest + /startup redirects to /login', (tester) async {
    final router = GoRouter(
      initialLocation: '/startup',
      redirect: nimonAuthRedirect,
      routes: [
        GoRoute(
          path: '/startup',
          builder: (_, __) => const Scaffold(body: Text('splash')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login_page')),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => const Scaffold(body: Text('home_mono')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [guestAuthSessionOverride],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/login');
    expect(find.text('login_page'), findsOneWidget);
  });

  testWidgets(
      'M17L: checking + /login redirects to /startup (no premature login)',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      redirect: nimonAuthRedirect,
      routes: [
        GoRoute(
          path: '/startup',
          builder: (_, __) => const Scaffold(body: Text('splash_body')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('login_body')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/startup');
    expect(find.text('splash_body'), findsOneWidget);
    expect(find.text('login_body'), findsNothing);
  });
}
