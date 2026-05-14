import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_token_store.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
import 'package:nimon/features/settings/settings_screen.dart';
import 'package:nimon/l10n/app_localizations.dart';

Widget _wrapRouter(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

class _FakeAuthTokenStore implements AuthTokenStore {
  StoredAuthTokens? _tokens;

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  _TestAuthSessionNotifier(AuthSessionState initial)
      : super(
          AuthRepository(apiBaseUrl: 'http://127.0.0.1:9'),
          _FakeAuthTokenStore(),
        ) {
    state = initial;
  }
}

class _FakeUserPreferencesRepository implements UserPreferencesRepository {
  _FakeUserPreferencesRepository({UserPreferences? initial})
      : _prefs = initial ?? UserPreferences.defaults;

  UserPreferences _prefs;

  final List<Map<String, String>> patchCalls = [];

  @override
  Future<UserPreferences> fetchPreferences() async => _prefs;

  @override
  Future<UserPreferences> patchPreferences({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  }) async {
    final call = <String, String>{
      if (appLocale != null) 'appLocale': appLocale,
      if (contentLocale != null) 'contentLocale': contentLocale,
      if (learningLanguage != null) 'learningLanguage': learningLanguage,
      if (themeMode != null) 'themeMode': themeMode,
      if (readingTextSize != null) 'readingTextSize': readingTextSize,
      if (showExplanations != null)
        'showExplanations': showExplanations.toString(),
    };
    patchCalls.add(call);
    _prefs = _prefs.copyWith(
      appLocale: appLocale,
      contentLocale: contentLocale,
      learningLanguage: learningLanguage,
      themeMode: themeMode,
      readingTextSize: readingTextSize,
      showExplanations: showExplanations,
    );
    return _prefs;
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const Scaffold(body: Text('Edit Profile')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
}

void main() {
  testWidgets('Settings screen loads and shows sections', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(
                AuthUser(id: 'u1', email: 'me@example.com'),
              ),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('App Language selector patches appLocale', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('App Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(fakeRepo.patchCalls.any((m) => m['appLocale'] == 'ja'), isTrue);
  });

  testWidgets('Content Community selector patches contentLocale',
      (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Content Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Myanmar'));
    await tester.pumpAndSettle();

    expect(fakeRepo.patchCalls.any((m) => m['contentLocale'] == 'my'), isTrue);
  });

  testWidgets('Learning Language selector shows Japanese option',
      (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learning Language'));
    await tester.pumpAndSettle();
    expect(find.text('Japanese'), findsWidgets);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('Theme selector patches themeMode', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(fakeRepo.patchCalls.any((m) => m['themeMode'] == 'dark'), isTrue);
  });

  testWidgets('Notifications row is disabled / coming soon', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    final tile =
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Notifications'));
    expect(tile.enabled, isFalse);
  });

  testWidgets('Edit profile navigates to /profile/edit', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/profile/edit');
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('Sign out logs out and routes to /login', (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/login');
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Reading text size selector patches readingTextSize',
      (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reading text size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();

    expect(
      fakeRepo.patchCalls.any((m) => m['readingTextSize'] == 'large'),
      isTrue,
    );
  });

  testWidgets('Explanation sentence toggle patches showExplanations',
      (tester) async {
    final fakeRepo = _FakeUserPreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => _TestAuthSessionNotifier(
              AuthSessionAuthenticated(AuthUser(id: 'u1', email: 'e@e.com')),
            ),
          ),
          userPreferencesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: _wrapRouter(_router()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(
      fakeRepo.patchCalls.any((m) => m['showExplanations'] == 'false'),
      isTrue,
    );
  });
}
