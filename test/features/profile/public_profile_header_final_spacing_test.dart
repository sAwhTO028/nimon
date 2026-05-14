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

class _FakeA5PublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeA5PublicRepo({
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

  Future<void> pumpRemoteProfile(WidgetTester tester) async {
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
            _FakeA5PublicRepo(
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
    'M14J-A5: action row to TabBar gap is tight (no large blank band)',
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
    'M14J-A5: avatar to identity block vertical spacing in range',
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

      if (nameRect.top >= avatarRect.bottom - 1) {
        final gap = nameRect.top - avatarRect.bottom;
        expect(gap, greaterThanOrEqualTo(8));
        expect(gap, lessThanOrEqualTo(40));
      } else {
        final identityRect = tester.getRect(identityFinder);
        final gap = identityRect.left - avatarRect.right;
        expect(gap, greaterThanOrEqualTo(12));
        expect(gap, lessThanOrEqualTo(32));
      }
    },
  );

  testWidgets(
    'M14J-A5: pinned TabBar header sliver and TabBar exist',
    (tester) async {
      await pumpRemoteProfile(tester);

      expect(
        find.byKey(const ValueKey('publicProfilePinnedTabBarHeader')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publicProfileTabBar')),
        findsOneWidget,
      );
    },
  );
}
