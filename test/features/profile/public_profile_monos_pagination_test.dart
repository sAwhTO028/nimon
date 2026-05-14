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
import 'package:nimon/features/profile/presentation/providers/public_profile_monos_notifier.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';

MonoFeedSummaryDto _mono(String id, int i) {
  return MonoFeedSummaryDto(
    monoId: id,
    title: 'Story $i',
    coverUrl: null,
    level: 'N5',
    category: '',
    categories: const [],
    description: 'D',
    writerId: 'u1',
    writerHandle: '@h',
    writerDisplayName: 'P',
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

class _FakeEmptyCollRepo extends RemoteCreatorCollectionsRepository {
  _FakeEmptyCollRepo()
      : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient((_) async => http.Response('unused', 500)),
        );

  @override
  Future<List<CreatorMonoCollection>> fetchPublicCollections(
    String userId,
  ) async =>
      const [];
}

class _RecordingPagingRepo extends RemotePublicCreatorProfileRepository {
  _RecordingPagingRepo()
      : super(
          apiBaseUrl: 'http://127.0.0.1:9',
          authHeaderBuilder: () async => <String, String>{},
          client: MockClient((_) async => http.Response('unused', 500)),
        );

  final List<Map<String, String?>> monoCalls = [];

  @override
  Future<PublicCreatorProfile> fetchPublicCreatorProfile(String userId) async =>
      PublicCreatorProfile(
        userId: userId,
        handle: '@h',
        displayName: 'PublicName',
        avatarUrl: null,
        coverImageUrl: null,
        bio: 'Bio',
        followersCount: 1,
        followingCount: 2,
        isFollowingByMe: false,
      );

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchCreatorMonoPage(
    String userId, {
    String? cursor,
    int? limit,
  }) async {
    monoCalls.add({
      'cursor': cursor,
      'limit': limit?.toString(),
    });
    if (cursor == null) {
      return PageResult<MonoFeedSummaryDto>(
        items: List.generate(10, (i) => _mono('m-$i', i)),
        nextCursor: 'c2',
        hasMore: true,
        totalCount: null,
      );
    }
    if (cursor == 'c2') {
      return PageResult<MonoFeedSummaryDto>(
        items: List.generate(3, (i) => _mono('m-p2-$i', i + 100)),
        nextCursor: null,
        hasMore: false,
        totalCount: null,
      );
    }
    return const PageResult<MonoFeedSummaryDto>(
      items: [],
      nextCursor: null,
      hasMore: false,
    );
  }
}

void main() {
  test('M14J-B: notifier initial + loadMore uses limit 10', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = _RecordingPagingRepo();
    final container = ProviderContainer(
      overrides: [
        remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(publicProfileMonosProvider('u1').notifier);
    await n.loadInitial('u1');
    expect(repo.monoCalls.first['limit'], '10');
    expect(repo.monoCalls.first['cursor'], isNull);

    await n.loadMore('u1');
    expect(repo.monoCalls.length, 2);
    expect(repo.monoCalls[1]['limit'], '10');
    expect(repo.monoCalls[1]['cursor'], 'c2');
    expect(n.state.items, hasLength(13));
  });

  test('M14J-B: sequential duplicate loadMore after end is ignored', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = _RecordingPagingRepo();
    final container = ProviderContainer(
      overrides: [
        remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(publicProfileMonosProvider('u1').notifier);
    await n.loadInitial('u1');
    await n.loadMore('u1');
    final after = repo.monoCalls.length;
    await n.loadMore('u1');
    expect(repo.monoCalls.length, after);
  });

  test('M14J-B: loadMore no-op when hasMore false', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = _RecordingPagingRepo();
    final container = ProviderContainer(
      overrides: [
        remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(publicProfileMonosProvider('u1').notifier);
    await n.loadInitial('u1');
    await n.loadMore('u1');
    expect(n.state.hasMore, isFalse);
    final callsAfterSecondPage = repo.monoCalls.length;
    await n.loadMore('u1');
    expect(repo.monoCalls.length, callsAfterSecondPage);
  });

  test('M14J-B: refresh replaces list and clears cursor chain', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = _RecordingPagingRepo();
    final container = ProviderContainer(
      overrides: [
        remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(publicProfileMonosProvider('u1').notifier);
    await n.loadInitial('u1');
    await n.loadMore('u1');
    expect(n.state.items, hasLength(13));
    await n.refresh('u1');
    expect(n.state.items, hasLength(10));
    expect(n.state.nextCursor, 'c2');
    expect(n.state.hasMore, isTrue);
  });

  testWidgets('M14J-B: public profile first paint loads 10 monos',
      (tester) async {
    final repo = _RecordingPagingRepo();
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
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeEmptyCollRepo(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.monoCalls.first['limit'], '10');
    expect(find.text('Story 0'), findsOneWidget);
    expect(find.text('Story 9'), findsOneWidget);
    expect(find.text('Story 100'), findsNothing);
  });

  testWidgets('M14J-B: scroll prefetches second page', (tester) async {
    final repo = _RecordingPagingRepo();
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

    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePublicCreatorProfileRepositoryProvider.overrideWithValue(repo),
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeEmptyCollRepo(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.monoCalls.length, 1);

    await tester.drag(
      find.text('Story 0').first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(repo.monoCalls.length, greaterThanOrEqualTo(2));
    expect(find.text('Story 100'), findsOneWidget);
  });

  testWidgets('M14J-B: Collections tab switch does not clear monos',
      (tester) async {
    final repo = _RecordingPagingRepo();
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
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
            _FakeEmptyCollRepo(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Monos'));
    await tester.pumpAndSettle();

    expect(find.text('Story 0'), findsOneWidget);
    expect(find.text('Story 9'), findsOneWidget);
  });

  testWidgets('M14J-B: TabBar still visible after monos fling', (tester) async {
    final repo = _RecordingPagingRepo();
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
      const Offset(0, -800),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publicProfileTabBar')), findsOneWidget);
  });
}
