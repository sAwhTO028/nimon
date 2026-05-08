import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/profile/profile_screen.dart';

void main() {
  testWidgets(
    'Published Monos multiselect: Add to collection, not Delete; snackbar',
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

      // Loose mock row on Published → Monos (remote drafts off).
      expect(find.text('朝の踏切'), findsOneWidget);

      await tester.longPress(find.text('朝の踏切'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multi Select'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Add to collection'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Add to collection'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collections are coming soon.'), findsOneWidget);
    },
  );

  testWidgets('Saved Monos multiselect: Unsave bulk action remains',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProfileScreen(
            repo: StoryRepoMock(),
            initialTabIndex: 2,
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

    expect(find.text('季節のあいさつ'), findsOneWidget);

    await tester.longPress(find.text('季節のあいさつ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi Select'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Unsave'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Add to collection'),
      findsNothing,
    );
  });
}
