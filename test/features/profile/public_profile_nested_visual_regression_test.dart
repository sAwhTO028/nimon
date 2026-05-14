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
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

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

class _FakeVisualRegressionPublicRepo
    extends RemotePublicCreatorProfileRepository {
  _FakeVisualRegressionPublicRepo({
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

AnimatedOpacity? _animatedOpacityAbove(Element element) {
  AnimatedOpacity? found;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is AnimatedOpacity) {
      found = w;
      return false;
    }
    return true;
  });
  return found;
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
      24,
      (i) => _monoDto('mono-$i', i),
    ),
    nextCursor: null,
    hasMore: false,
    totalCount: 24,
  );

  testWidgets(
    'M14J-A2: cover header is not pushed down with a large top gap',
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
              _FakeVisualRegressionPublicRepo(
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

      final coverFinder =
          find.byKey(const ValueKey('publicProfileCoverHeader'));
      expect(coverFinder, findsOneWidget);

      final coverTop = tester.getRect(coverFinder).top;
      final paddingTop = MediaQuery.paddingOf(
        tester.element(find.byType(NestedScrollView).first),
      ).top;

      // Regression: flexible header was bottom-aligned in a tall region,
      // leaving a large empty band above the cover. Keep the cover near the
      // top of the expanded header (status bar + small layout slack).
      expect(coverTop, lessThan(paddingTop + 96));
    },
  );

  testWidgets('M14J-A2: back button visible on nested public profile',
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
            _FakeVisualRegressionPublicRepo(
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

    expect(find.byType(NimonBackButton), findsWidgets);
  });

  testWidgets(
    'M14J-A2: TabBar has transparent M3 divider; indicator still set',
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
              _FakeVisualRegressionPublicRepo(
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

      final tabBar = tester.widget<TabBar>(
        find.byKey(const ValueKey('publicProfileTabBar')),
      );
      expect(tabBar.dividerColor, Colors.transparent);
      expect(tabBar.indicatorColor, isNotNull);
    },
  );

  testWidgets(
    'M14J-A: toolbar username + tabs still behave after A2 layout',
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
              _FakeVisualRegressionPublicRepo(
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

      expect(
        find.byKey(const ValueKey('publicProfileNestedScrollView')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publicProfileProfileInfoSliver')),
        findsOneWidget,
      );

      final titleEl = tester.element(
        find.byKey(const ValueKey('publicProfileToolbarUsername')),
      );
      expect(_animatedOpacityAbove(titleEl)!.opacity, lessThan(0.05));

      await tester.ensureVisible(
        find.byKey(const ValueKey('publicProfileMonosList')),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('publicProfileMonosList')),
        const Offset(0, -380),
      );
      await tester.pumpAndSettle();

      final after = _animatedOpacityAbove(
        tester.element(
          find.byKey(const ValueKey('publicProfileToolbarUsername')),
        ),
      );
      expect(after!.opacity, greaterThan(0.85));

      await tester.tap(find.widgetWithText(Tab, 'Collections'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('publicProfileCollectionsList')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(Tab, 'Monos'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('publicProfileMonosList')),
        findsOneWidget,
      );
    },
  );
}
