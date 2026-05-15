import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
import '../../support/auth_session_test_overrides.dart';
import '../../support/widget_test_network_and_assets.dart';

class _FakeUserPrefsRepo implements UserPreferencesRepository {
  @override
  Future<UserPreferences> fetchPreferences() async => UserPreferences.defaults;

  @override
  Future<UserPreferences> patchPreferences({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  }) async =>
      UserPreferences.defaults;
}

Override viewerSessionOverride(String id) => authSessionProvider.overrideWith(
      (_) => TestAuthSessionNotifierForTest(
        AuthSessionAuthenticated(
          AuthUser(id: id, email: 't@t.com'),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    installWidgetTestHttpOverridesPng();
  });

  tearDownAll(() {
    uninstallWidgetTestHttpOverrides();
  });
  final feedItemNav = MonoFeedItem(
    id: 'm14i_nav_mono',
    writerId: 'writer_uid_14i',
    writerName: 'M14I Writer',
    writerHandle: '@m14i',
    level: 'N5',
    contentType: MonoContentType.story,
    bodyText: '本文。少し長めにしてフッターを表示します。',
    storyDescription: 'Desc',
    title: 'M14I title',
    coverImageUrl: 'https://example.test/m14i_nav.png',
  );

  testWidgets('mono reader: username tap opens same public profile as avatar',
      (tester) async {
    String? pushed;

    final router = GoRouter(
      initialLocation: '/mono-reader',
      routes: [
        GoRoute(
          path: '/mono-reader',
          builder: (_, __) => MonoScreen(
            repo: StoryRepoMock(),
            initialItemsOverride: [feedItemNav],
            initialIndexOverride: 0,
            showTopControls: false,
          ),
        ),
        GoRoute(
          path: '/profile/public',
          builder: (_, st) {
            pushed = st.uri.queryParameters['userId'];
            return const Scaffold(body: Text('STUB_PUBLIC_PROFILE'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: WidgetTestPngAssetBundle(),
        child: ProviderScope(
          overrides: [
            viewerSessionOverride('viewer_14i'),
            userPreferencesRepositoryProvider
                .overrideWithValue(_FakeUserPrefsRepo()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('monoReaderCreatorUsername')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('monoReaderCreatorAvatar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monoReaderCreatorUsername')));
    await tester.pumpAndSettle();
    expect(pushed, 'writer_uid_14i');
    expect(find.text('STUB_PUBLIC_PROFILE'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    pushed = null;
    await tester.tap(find.byKey(const ValueKey('monoReaderCreatorAvatar')));
    await tester.pumpAndSettle();
    expect(pushed, 'writer_uid_14i');

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('monoReaderFollowButton')));
    await tester.pumpAndSettle();
    expect(find.text('STUB_PUBLIC_PROFILE'), findsNothing);
    expect(find.byKey(const ValueKey('monoReaderCreatorUsername')),
        findsOneWidget);
  });

  testWidgets('mono reader: missing writerId username does not crash',
      (tester) async {
    const noWriter = MonoFeedItem(
      id: 'm14i_no_writer',
      writerId: null,
      writerName: 'Anon',
      writerHandle: '',
      level: 'N5',
      contentType: MonoContentType.story,
      bodyText: 'Body',
      title: 'T',
      coverImageUrl: 'https://example.test/m14i_now.png',
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MonoScreen(
            repo: StoryRepoMock(),
            initialItemsOverride: [noWriter],
            showTopControls: false,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: WidgetTestPngAssetBundle(),
        child: ProviderScope(
          overrides: [
            authenticatedAuthSessionOverride,
            userPreferencesRepositoryProvider
                .overrideWithValue(_FakeUserPrefsRepo()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('monoReaderCreatorUsername')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
