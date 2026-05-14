import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/widgets/floating_dock_nav_bar.dart';

void main() {
  testWidgets(
    'Published Monos: scroll extent includes dock clearance; sub-tab sticky',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const bottomInset = 34.0;
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
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 520),
              padding: EdgeInsets.only(bottom: bottomInset),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final subTab = find.byKey(const ValueKey('profilePublishedSubTabRow'));
      final list = find.byKey(const ValueKey('profilePublishedMonosList'));
      expect(subTab, findsOneWidget);
      expect(list, findsOneWidget);

      final listCtx = tester.element(list);
      final dockZone = FloatingDockNavBar.dockOccupiedZoneHeight(listCtx);
      expect(
          dockZone,
          FloatingDockNavBar.dockOuterBottomPad +
              bottomInset +
              FloatingDockNavBar.dockPillHeight);

      final innerScrollable =
          find.descendant(of: list, matching: find.byType(Scrollable));
      final pos = tester.state<ScrollableState>(innerScrollable).position;
      expect(pos.maxScrollExtent, greaterThanOrEqualTo(0.0));

      final ySubBefore = tester.getTopLeft(subTab).dy;
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect((tester.getTopLeft(subTab).dy - ySubBefore).abs(), lessThan(2));

      if (pos.maxScrollExtent > 2) {
        await tester.drag(list, const Offset(0, -8000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final posEnd = tester.state<ScrollableState>(innerScrollable).position;
        expect(
          posEnd.pixels,
          closeTo(posEnd.maxScrollExtent, 8.0),
          reason: 'can scroll to end without clipping errors',
        );
        final rowRect = tester.getRect(find.text('朝の踏切'));
        final listRect = tester.getRect(list);
        expect(
          rowRect.bottom,
          lessThanOrEqualTo(listRect.bottom - dockZone + 4),
          reason: 'last row clears floating dock zone inside list viewport',
        );
      }

      if (!RemoteBackendConfig.useRemoteDrafts) {
        expect(
          find.byKey(const ValueKey('profilePublishedMonosRefreshIndicator')),
          findsNothing,
        );
      }
    },
  );
}
