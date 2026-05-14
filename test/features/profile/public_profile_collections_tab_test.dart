import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/public_creator_collection_detail_screen.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';

class _FakePublicProfileRepo extends RemotePublicCreatorProfileRepository {
  _FakePublicProfileRepo({
    required this.profile,
    required this.monoPage,
  }) : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient(
            (_) async => http.Response('unused', 500),
          ),
        );

  final PublicCreatorProfile profile;
  final PageResult<MonoFeedSummaryDto> monoPage;

  @override
  Future<PublicCreatorProfile> fetchPublicCreatorProfile(String userId) async =>
      profile;

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchCreatorMonoPage(
    String userId, {
    String? cursor,
    int? limit,
  }) async =>
      monoPage;
}

class _FakeCollRepo extends RemoteCreatorCollectionsRepository {
  _FakeCollRepo({
    required this.collections,
    this.detailPage,
  }) : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient(
            (_) async => http.Response('unused', 500),
          ),
        );

  final List<CreatorMonoCollection> collections;
  final PublicCollectionMonosPage? detailPage;

  @override
  Future<List<CreatorMonoCollection>> fetchPublicCollections(
    String userId,
  ) async =>
      collections;

  @override
  Future<PublicCollectionMonosPage> fetchPublicCollectionMonos(
    String userId,
    String collectionId, {
    String? cursor,
    int? limit,
  }) async =>
      detailPage ?? const PublicCollectionMonosPage(items: []);
}

void main() {
  final profile = PublicCreatorProfile(
    userId: 'u1',
    handle: '@h',
    displayName: 'Name',
    avatarUrl: null,
    coverImageUrl: null,
    bio: '',
    followersCount: 0,
    followingCount: 0,
    isFollowingByMe: false,
  );

  final emptyMonoPage = PageResult<MonoFeedSummaryDto>(
    items: const [],
    nextCursor: null,
    hasMore: false,
    totalCount: null,
  );

  testWidgets(
    'remote public profile shows Collections tab and empty state',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/profile/public?userId=u1',
        routes: [
          GoRoute(
            path: '/profile/public',
            builder: (c, s) => PublicProfileScreen(
              userId: s.uri.queryParameters['userId'],
            ),
            routes: [
              GoRoute(
                path: 'collections/detail',
                builder: (c, s) {
                  final extra = s.extra;
                  if (extra is! PublicCreatorCollectionDetailArgs) {
                    return const Scaffold(body: Text('bad'));
                  }
                  return PublicCreatorCollectionDetailScreen(args: extra);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/mono-reader',
            builder: (_, __) => const Scaffold(body: Text('reader')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remotePublicCreatorProfileRepositoryProvider.overrideWithValue(
              _FakePublicProfileRepo(profile: profile, monoPage: emptyMonoPage),
            ),
            remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
              _FakeCollRepo(collections: const []),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('publicProfileTabBar')),
        findsOneWidget,
      );
      expect(find.text('No published monos yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();

      expect(find.text('No collections yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'collection row shows title and item count; tap opens detail and reader',
    (tester) async {
      final coll = CreatorMonoCollection(
        id: 'col-1',
        ownerId: 'u1',
        title: 'My Pack',
        description: 'About',
        coverImageUrl: null,
        visibility: 'public',
        itemCount: 3,
        createdAt: '2026-01-01',
        updatedAt: '2026-01-02',
      );

      final monoDto = PublishedMonoListItemDto(
        id: 'm1',
        ownerId: 'u1',
        sourceDraftId: null,
        title: 'Mono T',
        category: '',
        level: 'N5',
        description: 'D',
        publishKind: 'read_only_v1',
        displayPublishKind: 'read_only',
        coverImageUrl: null,
        targetDurationLabel: null,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
        contentSummary: null,
      );

      final router = GoRouter(
        initialLocation: '/profile/public?userId=u1',
        routes: [
          GoRoute(
            path: '/profile/public',
            builder: (c, s) => PublicProfileScreen(
              userId: s.uri.queryParameters['userId'],
            ),
            routes: [
              GoRoute(
                path: 'collections/detail',
                builder: (c, s) {
                  final extra = s.extra;
                  if (extra is! PublicCreatorCollectionDetailArgs) {
                    return const Scaffold(body: Text('bad'));
                  }
                  return PublicCreatorCollectionDetailScreen(args: extra);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/mono-reader',
            builder: (_, __) => const Scaffold(body: Text('reader')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remotePublicCreatorProfileRepositoryProvider.overrideWithValue(
              _FakePublicProfileRepo(profile: profile, monoPage: emptyMonoPage),
            ),
            remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
              _FakeCollRepo(
                collections: [coll],
                detailPage: PublicCollectionMonosPage(items: [monoDto]),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();

      expect(find.text('3 stories'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

      await tester.tap(find.text('My Pack'));
      await tester.pumpAndSettle();

      expect(find.text('Mono T'), findsOneWidget);

      await tester.tap(find.text('Mono T'));
      await tester.pumpAndSettle();

      expect(find.text('reader'), findsOneWidget);
    },
  );

  testWidgets('M14I: public profile TabBar switches Monos and Collections',
      (tester) async {
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
          remotePublicCreatorProfileRepositoryProvider.overrideWithValue(
            _FakePublicProfileRepo(profile: profile, monoPage: emptyMonoPage),
          ),
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeCollRepo(collections: const []),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('publicProfileTabBar')), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Monos'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Collections'), findsOneWidget);
    expect(find.text('No published monos yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Collections'));
    await tester.pumpAndSettle();
    expect(find.text('No collections yet.'), findsOneWidget);
    expect(find.text('No published monos yet.'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Monos'));
    await tester.pumpAndSettle();
    expect(find.text('No published monos yet.'), findsOneWidget);
    expect(find.text('No collections yet.'), findsNothing);
  });

  testWidgets('M14I: public profile TabBar is visible in dark theme',
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
          remotePublicCreatorProfileRepositoryProvider.overrideWithValue(
            _FakePublicProfileRepo(profile: profile, monoPage: emptyMonoPage),
          ),
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeCollRepo(collections: const []),
          ),
        ],
        child: MaterialApp.router(
          theme: darkTheme,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('publicProfileTabBar')), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Monos'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Collections'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
