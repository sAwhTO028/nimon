import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/mono/mono_search_screen.dart';
import 'package:nimon/l10n/app_localizations.dart';

void main() {
  testWidgets('search entry navigates to Search screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/mono',
      routes: [
        GoRoute(
          path: '/mono',
          builder: (context, _) => Scaffold(
            body: Center(
              child: IconButton(
                key: const Key('shell_search_entry_probe'),
                icon: const Icon(Icons.search),
                onPressed: () => context.push('/mono/search'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/mono/search',
          builder: (_, __) => const MonoSearchScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell_search_entry_probe')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Find stories by title'), findsOneWidget);
    expect(router.state.uri.path, '/mono/search');
  });
}
