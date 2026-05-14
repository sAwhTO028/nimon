import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart'
    show PublicCreatorProfile, RemotePublicCreatorProfileRepository;
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';

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

class _FakeLayoutPublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeLayoutPublicRepo({
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

  Future<void> pumpRemoteProfile(WidgetTester tester) async {
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
            _FakeLayoutPublicRepo(
              profile: profile,
              monoPage: manyMonos,
            ),
          ),
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeCollRepo(const []),
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
    'M14J-A6: action row to TabBar gap is bounded (no huge blank band)',
    (tester) async {
      await pumpRemoteProfile(tester);

      final actionFinder = find.byKey(const ValueKey('publicProfileActionRow'));
      final tabBarFinder = find.byKey(const ValueKey('publicProfileTabBar'));
      expect(actionFinder, findsOneWidget);
      expect(tabBarFinder, findsOneWidget);

      final gap = tester.getRect(tabBarFinder).top -
          tester.getRect(actionFinder).bottom;
      expect(gap, greaterThanOrEqualTo(8));
      expect(gap, lessThanOrEqualTo(40));
    },
  );

  testWidgets(
    'M14J-A6: avatar and identity block spacing; no overlap',
    (tester) async {
      await pumpRemoteProfile(tester);

      final avatarFinder = find.byKey(const ValueKey('publicProfileAvatar'));
      final identityFinder =
          find.byKey(const ValueKey('publicProfileIdentityBlock'));
      expect(avatarFinder, findsOneWidget);
      expect(identityFinder, findsOneWidget);

      final avatarRect = tester.getRect(avatarFinder);
      final nameRect = tester.getRect(
        find.byKey(const ValueKey('publicProfileDisplayName')),
      );

      // M14J-A8: avatar lives in the cover hero; identity block is full-width so
      // its bounding rect can intersect the avatar horizontally — use headline.
      expect(nameRect.overlaps(avatarRect), isFalse);

      if (nameRect.top >= avatarRect.bottom - 1) {
        final gap = nameRect.top - avatarRect.bottom;
        expect(gap, greaterThanOrEqualTo(8));
        expect(gap, lessThanOrEqualTo(40));
      }
    },
  );

  testWidgets(
    'M14J-A6: identity not inside FlexibleSpaceBar; pinned tab header exists',
    (tester) async {
      await pumpRemoteProfile(tester);

      expect(
        find.descendant(
          of: find.byType(FlexibleSpaceBar),
          matching: find.byKey(const ValueKey('publicProfileIdentityBlock')),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('publicProfilePinnedTabBarHeader')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publicProfileTabBar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publicProfileProfileInfoSliver')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'M14J-A6: cover header is not pushed down with a large top gap',
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
              _FakeLayoutPublicRepo(
                profile: profile,
                monoPage: manyMonos,
              ),
            ),
            remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
              _FakeCollRepo(const []),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      final coverFinder =
          find.byKey(const ValueKey('publicProfileCoverHeader'));
      expect(coverFinder, findsOneWidget);

      final coverTop = tester.getRect(coverFinder).top;
      final paddingTop = MediaQuery.paddingOf(
        tester.element(find.byType(NestedScrollView).first),
      ).top;

      expect(coverTop, lessThan(paddingTop + 96));
    },
  );

  testWidgets(
    'M14J-A6: TabBar transparent divider; indicator set',
    (tester) async {
      await pumpRemoteProfile(tester);

      final tabBar = tester.widget<TabBar>(
        find.byKey(const ValueKey('publicProfileTabBar')),
      );
      expect(tabBar.dividerColor, Colors.transparent);
      expect(tabBar.indicatorColor, isNotNull);
    },
  );

  testWidgets(
    'M14J-A6: swipe Monos → Collections loads list',
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
              _FakeLayoutPublicRepo(
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
      await tester.pump();
      expect(find.text('No collections yet.'), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('SwipeTest Coll'), findsOneWidget);
    },
  );

  testWidgets(
    'M14J-A6: owner ProfileScreen does not use public profile TabBar key',
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
    },
  );
}
