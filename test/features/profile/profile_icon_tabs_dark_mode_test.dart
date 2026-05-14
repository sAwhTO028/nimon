import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/profile/profile_screen.dart';

void main() {
  testWidgets('Profile Published / Workspace / Saved tabs visible in dark mode',
      (tester) async {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

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
          theme: darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Published'), findsWidgets);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });
}
