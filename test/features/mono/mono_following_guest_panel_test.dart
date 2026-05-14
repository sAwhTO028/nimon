import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_following_guest_auth_panel.dart';
import 'package:nimon/l10n/app_localizations.dart';

void main() {
  testWidgets('M17K Following guest panel: title, body, Sign in button (EN)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: MonoFollowingGuestAuthPanel()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to see Following'), findsOneWidget);
    expect(
      find.text('Sign in to see stories from people you follow.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('M17K Following guest panel: dark mode uses onSurface colors',
      (tester) async {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );
    final scheme = darkTheme.colorScheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: MonoFollowingGuestAuthPanel()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.text('Sign in to see Following'),
    );
    expect(title.style?.color, scheme.onSurface);

    final body = tester.widget<Text>(
      find.text('Sign in to see stories from people you follow.'),
    );
    expect(body.style?.color, scheme.onSurfaceVariant);
  });
}
