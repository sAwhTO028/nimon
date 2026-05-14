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

class _FakeGapSwipePublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeGapSwipePublicRepo({
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

  testWidgets(
    'M14J-A3: action row to TabBar vertical gap is modest after measure',
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
              _FakeGapSwipePublicRepo(
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

      final actionFinder = find.byKey(const ValueKey('publicProfileActionRow'));
      final tabBarFinder = find.byKey(const ValueKey('publicProfileTabBar'));
      expect(actionFinder, findsOneWidget);
      expect(tabBarFinder, findsOneWidget);

      final gap = tester.getRect(tabBarFinder).top -
          tester.getRect(actionFinder).bottom;
      // Tight IG-style spacing: small positive gap only (no large blank band).
      expect(gap, lessThan(48));
      expect(gap, greaterThan(-12));
    },
  );

  testWidgets(
    'M14J-A3: swipe Monos → Collections loads list (no premature empty)',
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
              _FakeGapSwipePublicRepo(
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

      final tabView = find.byType(TabBarView);
      expect(tabView, findsOneWidget);

      await tester.fling(tabView, const Offset(-800, 0), 8000);
      await tester.pump();
      expect(find.text('No collections yet.'), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('SwipeTest Coll'), findsOneWidget);
      expect(find.text('No collections yet.'), findsNothing);
    },
  );

  testWidgets('M14J-A3: tap Collections still loads data', (tester) async {
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
            _FakeGapSwipePublicRepo(
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

    await tester.tap(find.widgetWithText(Tab, 'Collections'));
    await tester.pumpAndSettle();

    expect(find.text('SwipeTest Coll'), findsOneWidget);
  });

  testWidgets(
    'M14J-A3: swipe to Collections with empty mock shows empty after load',
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
              _FakeGapSwipePublicRepo(
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

      await tester.fling(
        find.byType(TabBarView),
        const Offset(-800, 0),
        8000,
      );
      await tester.pumpAndSettle();

      expect(find.text('No collections yet.'), findsOneWidget);
    },
  );
}
