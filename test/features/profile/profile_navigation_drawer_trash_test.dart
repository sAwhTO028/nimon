import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/profile_navigation_drawer.dart';

void main() {
  testWidgets('Profile drawer Actions includes Trash row', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ProfileNavigationDrawer(
                  hostContext: ctx,
                  displayName: 'Test',
                  handle: '@test',
                  closeDrawer: () async {},
                  lockScrollForHorizontalPan: ValueNotifier<bool>(false),
                  drawerMotion: AlwaysStoppedAnimation<double>(0),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trash'), findsOneWidget);
  });

  testWidgets('Profile drawer shows Edit profile action (owner only surface)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ProfileNavigationDrawer(
                  hostContext: ctx,
                  displayName: 'Test',
                  handle: '@test',
                  closeDrawer: () async {},
                  lockScrollForHorizontalPan: ValueNotifier<bool>(false),
                  drawerMotion: AlwaysStoppedAnimation<double>(0),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
