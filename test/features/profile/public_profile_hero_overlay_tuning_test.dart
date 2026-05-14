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
import 'package:nimon/features/profile/public_profile_remote_nested_scroll.dart';
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

class _FakeTunePublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeTunePublicRepo({
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

  Future<void> pumpPhone(WidgetTester tester) async {
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
            _FakeTunePublicRepo(
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

  testWidgets('M14J-A9: avatar fully visible on phone surface', (tester) async {
    await pumpPhone(tester);

    final avatar = find.byKey(const ValueKey('publicProfileAvatar'));
    expect(avatar, findsOneWidget);
    final r = tester.getRect(avatar);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(844));
    expect(r.height, greaterThan(40));
  });

  testWidgets('M14J-A9: stats row fully visible with labels', (tester) async {
    await pumpPhone(tester);

    final overlay = find.byKey(const ValueKey('publicProfileHeroOverlayRow'));
    expect(overlay, findsOneWidget);
    final r = tester.getRect(overlay);
    expect(r.top, greaterThanOrEqualTo(-2));
    expect(r.bottom, lessThanOrEqualTo(846));
    expect(find.text('Monos'), findsWidgets);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('M14J-A9: avatar and overlay sit inside cover bounds',
      (tester) async {
    await pumpPhone(tester);

    final coverRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileCoverHeader')));
    final avatarRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileAvatar')));
    expect(avatarRect.bottom, lessThanOrEqualTo(coverRect.bottom + 2));
    expect(avatarRect.top, greaterThanOrEqualTo(coverRect.top - 2));

    final overlayRect = tester
        .getRect(find.byKey(const ValueKey('publicProfileHeroOverlayRow')));
    expect(overlayRect.bottom, lessThanOrEqualTo(coverRect.bottom + 2));
    expect(overlayRect.top, greaterThanOrEqualTo(coverRect.top - 2));
  });

  testWidgets('M14J-A9: cover slot shorter than pre-A10 (backdrop + constants)',
      (tester) async {
    await pumpPhone(tester);

    final backdropRect = tester
        .getRect(find.byKey(const ValueKey('publicProfileCoverBackdrop')));
    // Backdrop fills the flexible region (toolbar paints over the top band).
    expect(
      backdropRect.height,
      lessThanOrEqualTo(
        PublicProfileRemoteNestedScroll.kRemotePublicCoverExpandedTotal + 8,
      ),
    );
    expect(
      PublicProfileRemoteNestedScroll.kRemotePublicCoverImageHeight,
      lessThanOrEqualTo(150),
    );
  });

  testWidgets('M14J-A9: identity starts below hero with bounded gap',
      (tester) async {
    await pumpPhone(tester);

    final avatarRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileAvatar')));
    final overlayRect = tester
        .getRect(find.byKey(const ValueKey('publicProfileHeroOverlayRow')));
    final identityRect = tester
        .getRect(find.byKey(const ValueKey('publicProfileIdentityBlock')));

    final heroBottom = avatarRect.bottom > overlayRect.bottom
        ? avatarRect.bottom
        : overlayRect.bottom;
    final gap = identityRect.top - heroBottom;
    expect(gap, greaterThanOrEqualTo(8));
    expect(gap, lessThanOrEqualTo(72));

    expect(
        find.byKey(const ValueKey('publicProfileDisplayName')), findsOneWidget);
    expect(find.byKey(const ValueKey('publicProfileHandle')), findsOneWidget);
    expect(find.byKey(const ValueKey('publicProfileBio')), findsOneWidget);
  });

  testWidgets('M14J-A9: action to TabBar and TabBar to first mono gaps bounded',
      (tester) async {
    await pumpPhone(tester);

    final action = find.byKey(const ValueKey('publicProfileActionRow'));
    final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
    final firstMono = find.byKey(const ValueKey('publicProfileFirstMonoRow'));

    final g1 = tester.getTopLeft(tabBar).dy - tester.getBottomLeft(action).dy;
    expect(g1, greaterThanOrEqualTo(8));
    expect(g1, lessThanOrEqualTo(40));

    final g2 =
        tester.getTopLeft(firstMono).dy - tester.getBottomLeft(tabBar).dy;
    expect(g2, greaterThanOrEqualTo(8));
    expect(g2, lessThanOrEqualTo(40));
  });

  testWidgets('M14J-A9: TabBar still visible after monos fling',
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
            _FakeTunePublicRepo(profile: profile, monoPage: manyMonos),
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
  });

  testWidgets('M14J-A9: swipe Monos → Collections loads list', (tester) async {
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
            _FakeTunePublicRepo(profile: profile, monoPage: manyMonos),
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
  });

  testWidgets('M14J-A9: owner ProfileScreen has no public profile keys',
      (tester) async {
    final ownerRouter = GoRouter(
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
        child: MaterialApp.router(routerConfig: ownerRouter),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publicProfileTabBar')), findsNothing);
    expect(
      find.byKey(const ValueKey('publicProfileNestedScrollView')),
      findsNothing,
    );
  });
}
