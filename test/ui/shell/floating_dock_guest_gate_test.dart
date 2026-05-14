import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/shell/floating_dock_tab_handler.dart';
import 'package:nimon/widgets/floating_dock_nav_bar.dart';

import '../../support/auth_session_test_overrides.dart';

void main() {
  testWidgets(
    'M17K guest: Add tab shows sign-in sheet and does not open /create',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/mono',
        routes: [
          GoRoute(
            path: '/mono',
            builder: (context, state) => Scaffold(
              body: const Center(child: Text('mono_body')),
              bottomNavigationBar: FloatingDockNavBar(
                selectedIndex: 0,
                theme: Theme.of(context),
                onItemTapped: (i) {
                  unawaited(
                    handleFloatingDockTabSelection(
                      context,
                      navigationShell: null,
                      index: i,
                      openCreate: (ctx) => ctx.push('/create'),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('create_page'))),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('login_page'))),
          ),
          GoRoute(
            path: '/more',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('more_page'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestAuthSessionOverride],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.text('create_page'), findsNothing);
      expect(router.state.uri.path, '/mono');
    },
  );

  testWidgets(
    'M17K guest: Profile tab shows sign-in sheet and does not open /more',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/mono',
        routes: [
          GoRoute(
            path: '/mono',
            builder: (context, state) => Scaffold(
              body: const Center(child: Text('mono_body')),
              bottomNavigationBar: FloatingDockNavBar(
                selectedIndex: 0,
                theme: Theme.of(context),
                onItemTapped: (i) {
                  unawaited(
                    handleFloatingDockTabSelection(
                      context,
                      navigationShell: null,
                      index: i,
                      openCreate: (ctx) => ctx.push('/create'),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('create_page'))),
          ),
          GoRoute(
            path: '/more',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('more_page'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [guestAuthSessionOverride],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.text('more_page'), findsNothing);
      expect(router.state.uri.path, '/mono');
    },
  );

  testWidgets(
    'M17K authenticated: Add opens /create; Profile opens /more',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/mono',
        routes: [
          GoRoute(
            path: '/mono',
            builder: (context, state) => Scaffold(
              body: const Center(child: Text('mono_body')),
              bottomNavigationBar: FloatingDockNavBar(
                selectedIndex: 0,
                theme: Theme.of(context),
                onItemTapped: (i) {
                  unawaited(
                    handleFloatingDockTabSelection(
                      context,
                      navigationShell: null,
                      index: i,
                      openCreate: (ctx) => ctx.push('/create'),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('create_page'))),
          ),
          GoRoute(
            path: '/more',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('more_page'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authenticatedAuthSessionOverride],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/create');
      expect(find.text('create_page'), findsOneWidget);

      router.go('/mono');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/more');
      expect(find.text('more_page'), findsOneWidget);
    },
  );
}
