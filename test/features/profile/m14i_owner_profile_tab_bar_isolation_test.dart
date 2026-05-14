import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/profile/profile_screen.dart';

void main() {
  testWidgets(
    'M14I: owner ProfileScreen does not use public profile TabBar key',
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

      expect(
        find.byKey(const ValueKey('publicProfileTabBar')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('publicProfileNestedScrollView')),
        findsNothing,
      );
      expect(find.text('Published'), findsWidgets);
    },
  );
}
