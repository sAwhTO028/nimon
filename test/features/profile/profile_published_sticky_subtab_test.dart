import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/profile_screen.dart';

void main() {
  testWidgets(
    'Published Monos refresh indicator only when remote drafts enabled',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProfileScreen(
              repo: StoryRepoMock(),
              initialTabIndex: 0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final refreshFinder = find.byKey(
        const ValueKey('profilePublishedMonosRefreshIndicator'),
      );
      if (RemoteBackendConfig.useRemoteDrafts) {
        expect(refreshFinder, findsOneWidget);
      } else {
        expect(refreshFinder, findsNothing);
      }
    },
  );

  testWidgets(
    'Published Monos: sub-tab row stays fixed while list content scrolls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProfileScreen(
              repo: StoryRepoMock(),
              initialTabIndex: 0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final subTab = find.byKey(const ValueKey('profilePublishedSubTabRow'));
      final list = find.byKey(const ValueKey('profilePublishedMonosList'));
      expect(subTab, findsOneWidget);
      expect(list, findsOneWidget);
      expect(find.text('朝の踏切'), findsOneWidget);

      final innerScrollableFinder =
          find.descendant(of: list, matching: find.byType(Scrollable));
      final maxExtent = tester
          .state<ScrollableState>(innerScrollableFinder)
          .position
          .maxScrollExtent;

      final ySubBefore = tester.getTopLeft(subTab).dy;
      final yRowBefore = tester.getTopLeft(find.text('朝の踏切')).dy;

      await tester.drag(list, const Offset(0, -140));
      await tester.pumpAndSettle();

      final ySubAfter = tester.getTopLeft(subTab).dy;
      expect((ySubAfter - ySubBefore).abs(), lessThan(2));

      final yRowAfter = tester.getTopLeft(find.text('朝の踏切')).dy;
      if (maxExtent > 8) {
        expect((yRowAfter - yRowBefore).abs(), greaterThan(1));
      }
    },
  );

  testWidgets(
    'Published Collections (mock): sub-tab stays fixed; list has key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProfileScreen(
              repo: StoryRepoMock(),
              initialTabIndex: 0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Collections'));
      await tester.pump();
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();

      final collectionsList =
          find.byKey(const ValueKey('profilePublishedCollectionsList'));
      final subTab = find.byKey(const ValueKey('profilePublishedSubTabRow'));
      expect(collectionsList, findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      final ySubBefore = tester.getTopLeft(subTab).dy;
      await tester.drag(collectionsList, const Offset(0, -120));
      await tester.pumpAndSettle();
      final ySubAfter = tester.getTopLeft(subTab).dy;
      expect((ySubAfter - ySubBefore).abs(), lessThan(2));
    },
  );

  testWidgets('Published sub-tab labels visible in dark theme', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProfileScreen(
            repo: StoryRepoMock(),
            initialTabIndex: 0,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ThemeData.dark(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profilePublishedSubTabRow')),
        findsOneWidget);
    expect(find.text('Monos'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
  });
}
