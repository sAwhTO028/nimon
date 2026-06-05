import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';
import 'package:nimon/features/profile/presentation/providers/public_profile_monos_notifier.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';

class _TrackingPublicProfileRepo extends RemotePublicCreatorProfileRepository {
  _TrackingPublicProfileRepo()
      : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
          client: MockClient((_) async => http.Response('unused', 500)),
        );

  final List<({String? contentLocale, String? learningLanguage})> monoCalls =
      [];

  @override
  Future<PublicCreatorProfile> fetchPublicCreatorProfile(String userId) async {
    return PublicCreatorProfile(
      userId: userId,
      handle: '@h',
      displayName: 'Name',
      avatarUrl: null,
      coverImageUrl: null,
      bio: '',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
  }

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchCreatorMonoPage(
    String userId, {
    String? cursor,
    int? limit,
    CatalogDiscoveryLens? catalogLens,
  }) async {
    monoCalls.add((
      contentLocale: catalogLens?.contentLocale,
      learningLanguage: catalogLens?.learningLanguage,
    ));
    return const PageResult<MonoFeedSummaryDto>(
      items: [],
      nextCursor: null,
      hasMore: false,
      totalCount: null,
    );
  }
}

class _TestUserPreferencesNotifier extends UserPreferencesNotifier {
  _TestUserPreferencesNotifier(
    Ref ref, {
    required UserPreferencesState initial,
    required UserPreferencesRepository repo,
  }) : super(ref, repo: repo) {
    state = initial;
  }

  @override
  Future<void> load() async {}

  void setPrefs(UserPreferences prefs) {
    state = state.copyWith(prefs: prefs);
  }
}

class _NoOpPrefsRepo implements UserPreferencesRepository {
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

void main() {
  test('PublicProfileMonosNotifier sends catalog lens from prefs', () async {
    final repo = _TrackingPublicProfileRepo();
    final container = ProviderContainer(
      overrides: [
        remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
        userPreferencesNotifierProvider.overrideWith(
          (ref) => _TestUserPreferencesNotifier(
            ref,
            repo: _NoOpPrefsRepo(),
            initial: const UserPreferencesState(
              loading: false,
              saving: false,
              prefs: UserPreferences(
                appLocale: 'system',
                contentLocale: 'my',
                learningLanguage: 'en',
                themeMode: 'system',
                readingTextSize: 'standard',
                showExplanations: true,
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(publicProfileMonosProvider('u1').notifier)
        .loadInitial('u1');

    expect(repo.monoCalls, hasLength(1));
    expect(repo.monoCalls.single.contentLocale, 'my');
    expect(repo.monoCalls.single.learningLanguage, 'en');
  });

  testWidgets('public profile Monos refreshes when contentLocale changes',
      (tester) async {
    final repo = _TrackingPublicProfileRepo();
    _TestUserPreferencesNotifier? prefsNotifier;

    final router = GoRouter(
      initialLocation: '/profile/public?userId=u1',
      routes: [
        GoRoute(
          path: '/profile/public',
          builder: (c, s) => PublicProfileScreen(
            userId: s.uri.queryParameters['userId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
          userPreferencesNotifierProvider.overrideWith((ref) {
            prefsNotifier = _TestUserPreferencesNotifier(
              ref,
              repo: _NoOpPrefsRepo(),
              initial: const UserPreferencesState(
                loading: false,
                saving: false,
                prefs: UserPreferences(
                  appLocale: 'system',
                  contentLocale: 'en',
                  learningLanguage: 'ja',
                  themeMode: 'system',
                  readingTextSize: 'standard',
                  showExplanations: true,
                ),
              ),
            );
            return prefsNotifier!;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final callsAfterLoad = repo.monoCalls.length;
    expect(callsAfterLoad, greaterThanOrEqualTo(1));

    prefsNotifier!.setPrefs(
      prefsNotifier!.state.prefs.copyWith(contentLocale: 'my'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.monoCalls.length, greaterThan(callsAfterLoad));
    expect(repo.monoCalls.last.contentLocale, 'my');
    expect(repo.monoCalls.last.learningLanguage, 'ja');
  });

  testWidgets('public profile Monos refreshes when learningLanguage changes',
      (tester) async {
    final repo = _TrackingPublicProfileRepo();
    _TestUserPreferencesNotifier? prefsNotifier;

    final router = GoRouter(
      initialLocation: '/profile/public?userId=u1',
      routes: [
        GoRoute(
          path: '/profile/public',
          builder: (c, s) => PublicProfileScreen(
            userId: s.uri.queryParameters['userId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
          userPreferencesNotifierProvider.overrideWith((ref) {
            prefsNotifier = _TestUserPreferencesNotifier(
              ref,
              repo: _NoOpPrefsRepo(),
              initial: const UserPreferencesState(
                loading: false,
                saving: false,
                prefs: UserPreferences(
                  appLocale: 'system',
                  contentLocale: 'my',
                  learningLanguage: 'ja',
                  themeMode: 'system',
                  readingTextSize: 'standard',
                  showExplanations: true,
                ),
              ),
            );
            return prefsNotifier!;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final callsAfterLoad = repo.monoCalls.length;

    prefsNotifier!.setPrefs(
      prefsNotifier!.state.prefs.copyWith(learningLanguage: 'en'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.monoCalls.length, greaterThan(callsAfterLoad));
    expect(repo.monoCalls.last.contentLocale, 'my');
    expect(repo.monoCalls.last.learningLanguage, 'en');
  });
}
