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
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart'
    show PublicCreatorProfile, RemotePublicCreatorProfileRepository;
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';
import 'package:nimon/data/story_repo_mock.dart';

MonoFeedSummaryDto _monoDto(String id, int i) {
  return MonoFeedSummaryDto(
    monoId: id,
    title: 'Story $i',
    coverUrl: null,
    level: 'N5',
    category: '',
    categories: const [],
    description: 'Description $i',
    writerId: 'u1',
    writerHandle: '@h',
    writerDisplayName: 'PublicName',
    writerAvatarUrl: '',
    publishedAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-02T00:00:00Z',
    likesCount: 0,
    hasAudio: false,
    isBookmarkedByMe: false,
    myReaction: null,
    shareUrl: null,
    publishKind: 'read_only_v1',
    accessType: 'public',
  );
}

class _FakeGapPublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeGapPublicRepo({
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

class _FakeEmptyCollRepo extends RemoteCreatorCollectionsRepository {
  _FakeEmptyCollRepo()
      : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient(
            (_) async => http.Response('unused', 500),
          ),
        );

  @override
  Future<List<CreatorMonoCollection>> fetchPublicCollections(
    String userId,
  ) async =>
      const [];
}

class _FakeCollRepo extends RemoteCreatorCollectionsRepository {
  _FakeCollRepo(this.collections)
      : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient(
            (_) async => http.Response('unused', 500),
          ),
        );

  final List<CreatorMonoCollection> collections;

  @override
  Future<List<CreatorMonoCollection>> fetchPublicCollections(
    String userId,
  ) async =>
      collections;
}

void main() {
  final profile = PublicCreatorProfile(
    userId: 'u1',
    handle: '@handle',
    displayName: 'PublicName',
    avatarUrl: null,
    coverImageUrl: null,
    bio: 'Bio line for layout.',
    followersCount: 2,
    followingCount: 3,
    isFollowingByMe: false,
  );

  final manyMonos = PageResult<MonoFeedSummaryDto>(
    items: List<MonoFeedSummaryDto>.generate(
      8,
      (i) => _monoDto('mono-$i', i),
    ),
    nextCursor: null,
    hasMore: false,
    totalCount: 8,
  );

  final swipeColl = CreatorMonoCollection(
    id: 'swipe-coll',
    ownerId: 'u1',
    title: 'SwipeTest Coll',
    description: null,
    coverImageUrl: null,
    visibility: 'public',
    itemCount: 2,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-02T00:00:00Z',
  );

  Future<void> pumpRemote(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            _FakeGapPublicRepo(
              profile: profile,
              monoPage: manyMonos,
            ),
          ),
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeEmptyCollRepo(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'M14J-A7: action row to TabBar vertical gap is bounded',
    (tester) async {
      await pumpRemote(tester);

      final action = find.byKey(const ValueKey('publicProfileActionRow'));
      final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
      expect(action, findsOneWidget);
      expect(tabBar, findsOneWidget);

      final actionBottom = tester.getBottomLeft(action).dy;
      final tabTop = tester.getTopLeft(tabBar).dy;
      final gap = tabTop - actionBottom;
      expect(gap, greaterThanOrEqualTo(8));
      expect(gap, lessThanOrEqualTo(40));
    },
  );

  testWidgets(
    'M14J-A7: TabBar to first mono row gap is bounded',
    (tester) async {
      await pumpRemote(tester);

      final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
      final firstMono = find.byKey(const ValueKey('publicProfileFirstMonoRow'));
      expect(tabBar, findsOneWidget);
      expect(firstMono, findsOneWidget);

      final tabBottom = tester.getBottomLeft(tabBar).dy;
      final firstTop = tester.getTopLeft(firstMono).dy;
      final gap = firstTop - tabBottom;
      expect(gap, greaterThanOrEqualTo(8));
      expect(gap, lessThanOrEqualTo(40));
    },
  );

  testWidgets(
    'M14J-A7: both vertical gaps stay within hard max',
    (tester) async {
      await pumpRemote(tester);

      final action = find.byKey(const ValueKey('publicProfileActionRow'));
      final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
      final firstMono = find.byKey(const ValueKey('publicProfileFirstMonoRow'));

      final g1 = tester.getTopLeft(tabBar).dy - tester.getBottomLeft(action).dy;
      final g2 =
          tester.getTopLeft(firstMono).dy - tester.getBottomLeft(tabBar).dy;

      expect(g1, greaterThanOrEqualTo(8));
      expect(g1, lessThanOrEqualTo(40));
      expect(g2, greaterThanOrEqualTo(8));
      expect(g2, lessThanOrEqualTo(40));
    },
  );

  testWidgets(
    'M14J-A7: TabBar still visible after scrolling monos list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
              _FakeGapPublicRepo(
                profile: profile,
                monoPage: manyMonos,
              ),
            ),
            remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
              _FakeEmptyCollRepo(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      await tester.fling(
        find.text('Story 0').first,
        const Offset(0, -700),
        2400,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('publicProfileTabBar')), findsOneWidget);
    },
  );

  testWidgets(
    'M14J-A7: swipe Monos → Collections still loads list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
              _FakeGapPublicRepo(
                profile: profile,
                monoPage: manyMonos,
              ),
            ),
            remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
              _FakeCollRepo([swipeColl]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(TabBarView),
        const Offset(-800, 0),
        8000,
      );
      await tester.pumpAndSettle();

      expect(find.text('SwipeTest Coll'), findsOneWidget);
    },
  );

  testWidgets(
    'M14J-A7: owner ProfileScreen does not expose public TabBar keys',
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

      expect(find.byKey(const ValueKey('publicProfileTabBar')), findsNothing);
      expect(
        find.byKey(const ValueKey('publicProfileNestedScrollView')),
        findsNothing,
      );
    },
  );
}
