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
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';
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

MonoFeedSummaryDto _monoWriterPage({
  required String writerDisplayName,
  required String writerHandle,
}) {
  return MonoFeedSummaryDto(
    monoId: 'm-writer',
    title: 'T',
    coverUrl: null,
    level: 'N5',
    category: '',
    categories: const [],
    description: 'd',
    writerId: 'u1',
    writerHandle: writerHandle,
    writerDisplayName: writerDisplayName,
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

class _FakeIdentityPublicRepo extends RemotePublicCreatorProfileRepository {
  _FakeIdentityPublicRepo({
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

final _manyMonos = PageResult<MonoFeedSummaryDto>(
  items: List<MonoFeedSummaryDto>.generate(
    8,
    (i) => _monoDto('mono-$i', i),
  ),
  nextCursor: null,
  hasMore: false,
  totalCount: 8,
);

Future<void> _pumpPublicProfile(
  WidgetTester tester, {
  required PublicCreatorProfile profile,
  PageResult<MonoFeedSummaryDto>? monoPage,
  ThemeData? theme,
}) async {
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
          _FakeIdentityPublicRepo(
            profile: profile,
            monoPage: monoPage ?? _manyMonos,
          ),
        ),
        remoteCreatorCollectionsRepositoryProvider.overrideWithValue(
          _FakeEmptyCollRepo(),
        ),
      ],
      child: MaterialApp.router(
        theme: theme,
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pumpAndSettle();
}

void main() {
  group('PublicCreatorProfile identity fallbacks', () {
    test('main display uses displayName when present', () {
      const p = PublicCreatorProfile(
        userId: 'u1',
        handle: null,
        displayName: 'Alice',
        username: 'alice_login',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
        followersCount: 0,
        followingCount: 0,
        isFollowingByMe: false,
      );
      expect(p.publicProfileMainDisplayName, 'Alice');
      expect(p.publicProfileSecondaryHandleLine('Alice'), '@alice_login');
    });

    test('username fills handle row when handle empty', () {
      const p = PublicCreatorProfile(
        userId: 'u1',
        handle: null,
        displayName: 'Bob',
        username: 'bobcodes',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
        followersCount: 0,
        followingCount: 0,
        isFollowingByMe: false,
      );
      expect(p.publicProfileSecondaryHandleLine('Bob'), '@bobcodes');
    });

    test('main display falls back to username when displayName empty', () {
      const p = PublicCreatorProfile(
        userId: 'u1',
        handle: null,
        displayName: null,
        username: 'casey',
        avatarUrl: null,
        coverImageUrl: null,
        bio: 'Bio only.',
        followersCount: 0,
        followingCount: 0,
        isFollowingByMe: false,
      );
      expect(p.publicProfileMainDisplayName, 'casey');
      expect(p.publicProfileSecondaryHandleLine('casey'), '@casey');
    });

    test('secondary line omitted when it matches main exactly', () {
      const p = PublicCreatorProfile(
        userId: 'u1',
        handle: '@solo',
        displayName: null,
        username: null,
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
        followersCount: 0,
        followingCount: 0,
        isFollowingByMe: false,
      );
      expect(p.publicProfileMainDisplayName, '@solo');
      expect(p.publicProfileSecondaryHandleLine('@solo'), isNull);
    });

    test('fromJson maps optional username', () {
      final p = PublicCreatorProfile.fromJson({
        'userId': 'u1',
        'displayName': null,
        'handle': null,
        'username': 'from_json_user',
        'followersCount': 0,
        'followingCount': 0,
        'isFollowingByMe': false,
      });
      expect(p.username, 'from_json_user');
      expect(p.publicProfileMainDisplayName, 'from_json_user');
      expect(
        p.publicProfileSecondaryHandleLine('from_json_user'),
        '@from_json_user',
      );
    });

    test('applyMonoWriterIdentityFallback fills missing display and handle',
        () {
      const base = PublicCreatorProfile(
        userId: 'u1',
        handle: null,
        displayName: null,
        username: null,
        avatarUrl: null,
        coverImageUrl: null,
        bio: 'Bio',
        followersCount: 0,
        followingCount: 0,
        isFollowingByMe: false,
      );
      final out = applyMonoWriterIdentityFallback(
        base,
        monoWriterId: 'u1',
        monoWriterName: 'Baby Cooky',
        monoWriterHandle: '@baby_cute',
      );
      expect(out.displayName, 'Baby Cooky');
      expect(out.handle, '@baby_cute');
    });
  });

  group('M17B-2 PublicCreatorProfile.fromJson alternate shapes', () {
    test('reads display_name and handle from nested profile map', () {
      final p = PublicCreatorProfile.fromJson({
        'userId': 'u1',
        'profile': {
          'display_name': 'Nested Name',
          'handle': 'nested_handle',
          'bio': 'Nested bio.',
        },
        'followersCount': 0,
        'followingCount': 0,
        'isFollowingByMe': false,
      });
      expect(p.displayName, 'Nested Name');
      expect(p.handle, 'nested_handle');
      expect(p.bio, 'Nested bio.');
    });

    test('merges writerDisplayName from nested writer object', () {
      final p = PublicCreatorProfile.fromJson({
        'userId': 'u1',
        'writer': {
          'writerDisplayName': 'Writer Only',
          'writerHandle': '@wo',
        },
        'followersCount': 0,
        'followingCount': 0,
        'isFollowingByMe': false,
      });
      expect(p.displayName, 'Writer Only');
      expect(p.handle, '@wo');
    });
  });

  testWidgets('M17B: display name visible when displayName exists',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@writer',
      displayName: 'Visible Name',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 1,
      followingCount: 2,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    final name = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileDisplayName')),
    );
    expect(name.data, 'Visible Name');
  });

  testWidgets('M17B: handle visible when handle exists', (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: 'plainhandle',
      displayName: 'N',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(find.byKey(const ValueKey('publicProfileHandle')), findsOneWidget);
    expect(find.text('@plainhandle'), findsOneWidget);
  });

  testWidgets('M17B: username fallback visible when handle empty',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: 'Pat',
      username: 'pat_login',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(find.text('@pat_login'), findsOneWidget);
  });

  testWidgets('M17B: username used as main line when displayName empty',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: null,
      username: 'solo_login',
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Only bio and username.',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    final mainText = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileDisplayName')),
    );
    expect(mainText.data, 'solo_login');
    expect(find.text('@solo_login'), findsOneWidget);
  });

  testWidgets('M17B: display name uses explicit onSurface color (light)',
      (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'ColorName',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(
      tester,
      profile: profile,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
    );
    final name = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileDisplayName')),
    );
    expect(name.style?.color, scheme.onSurface);

    final handle = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileHandle')),
    );
    expect(handle.style?.color, scheme.onSurfaceVariant);
  });

  testWidgets('M17B: display name uses explicit onSurface color (dark)',
      (tester) async {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'DarkName',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(
      tester,
      profile: profile,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
    );
    final name = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileDisplayName')),
    );
    expect(name.style?.color, scheme.onSurface);
  });

  testWidgets('M17B: bio remains visible below handle', (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: 'belowme',
      displayName: 'Top',
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Second line of bio for layout.',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(find.byKey(const ValueKey('publicProfileBio')), findsOneWidget);
    expect(find.text('Second line of bio for layout.'), findsOneWidget);

    final nameTop = tester
        .getTopLeft(find.byKey(const ValueKey('publicProfileDisplayName')))
        .dy;
    final handleTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileHandle'))).dy;
    final bioTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileBio'))).dy;
    expect(handleTop, greaterThan(nameTop));
    expect(bioTop, greaterThan(handleTop));
  });

  testWidgets('M17B: action row to TabBar gap stays <= 40', (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'Gap User',
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Bio.',
      followersCount: 2,
      followingCount: 3,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);

    final action = find.byKey(const ValueKey('publicProfileActionRow'));
    final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
    final gap = tester.getTopLeft(tabBar).dy - tester.getBottomLeft(action).dy;
    expect(gap, greaterThanOrEqualTo(8));
    expect(gap, lessThanOrEqualTo(40));
  });

  testWidgets('M17B: TabBar to first mono gap stays <= 40', (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'Gap User',
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Bio.',
      followersCount: 2,
      followingCount: 3,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);

    final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
    final firstMono = find.byKey(const ValueKey('publicProfileFirstMonoRow'));
    final gap =
        tester.getTopLeft(firstMono).dy - tester.getBottomLeft(tabBar).dy;
    expect(gap, greaterThanOrEqualTo(8));
    expect(gap, lessThanOrEqualTo(40));
  });

  testWidgets('M17B: avatar and stats overlay remain on screen',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'Stats',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 9,
      followingCount: 4,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);

    final avatar = find.byKey(const ValueKey('publicProfileAvatar'));
    final overlay = find.byKey(const ValueKey('publicProfileHeroOverlayRow'));
    expect(avatar, findsOneWidget);
    expect(overlay, findsOneWidget);
    final avatarRect = tester.getRect(avatar);
    expect(avatarRect.top, greaterThanOrEqualTo(0));
    expect(avatarRect.bottom, lessThanOrEqualTo(844));
    expect(avatarRect.height, greaterThan(40));

    expect(find.text('Monos'), findsWidgets);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('M17B: monos tab keeps remote scroll bucket (pagination wiring)',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@h',
      displayName: 'P',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(
      find.byKey(const PageStorageKey<String>('public_profile_remote_monos')),
      findsOneWidget,
    );
  });

  testWidgets('M17B-2: Case 1 identity above bio with rects in bounds',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: '@case1h',
      displayName: 'Case One',
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Learn for JLPT levle.',
      followersCount: 1,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(
        find.byKey(const ValueKey('publicProfileDisplayName')), findsOneWidget);
    expect(find.byKey(const ValueKey('publicProfileHandle')), findsOneWidget);
    expect(find.byKey(const ValueKey('publicProfileBio')), findsOneWidget);

    final nameRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileDisplayName')));
    final handleRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileHandle')));
    final bioRect =
        tester.getRect(find.byKey(const ValueKey('publicProfileBio')));
    expect(nameRect.top, lessThan(handleRect.top));
    expect(handleRect.top, lessThan(bioRect.top));
    expect(nameRect.top, greaterThanOrEqualTo(0));
    expect(nameRect.bottom, lessThanOrEqualTo(844));
    expect(handleRect.top, greaterThanOrEqualTo(0));
    expect(handleRect.bottom, lessThanOrEqualTo(844));
    expect(bioRect.top, greaterThanOrEqualTo(0));

    final action = find.byKey(const ValueKey('publicProfileActionRow'));
    final tabBar = find.byKey(const ValueKey('publicProfileTabBar'));
    final firstMono = find.byKey(const ValueKey('publicProfileFirstMonoRow'));
    final g1 = tester.getTopLeft(tabBar).dy - tester.getBottomLeft(action).dy;
    final g2 =
        tester.getTopLeft(firstMono).dy - tester.getBottomLeft(tabBar).dy;
    expect(g1, lessThanOrEqualTo(40));
    expect(g2, lessThanOrEqualTo(40));
  });

  testWidgets('M17B-2: Case 2 displayName only + bio, no handle row',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: 'Solo Display',
      username: null,
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Bio without handle.',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('publicProfileDisplayName')))
          .data,
      'Solo Display',
    );
    expect(find.byKey(const ValueKey('publicProfileHandle')), findsNothing);
    final nameTop = tester
        .getTopLeft(find.byKey(const ValueKey('publicProfileDisplayName')))
        .dy;
    final bioTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileBio'))).dy;
    expect(bioTop, greaterThan(nameTop));
  });

  testWidgets('M17B-2: Case 3 display empty, handle drives main + secondary',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: 'onlyhandle',
      displayName: null,
      username: null,
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Bio three.',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    await _pumpPublicProfile(tester, profile: profile);
    final main = tester.widget<Text>(
      find.byKey(const ValueKey('publicProfileDisplayName')),
    );
    expect(main.data, 'onlyhandle');
    expect(find.byKey(const ValueKey('publicProfileHandle')), findsOneWidget);
    expect(find.text('@onlyhandle'), findsOneWidget);
  });

  testWidgets('M17B-2: Case 4 Creator fallback above bio when feed empty',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: null,
      username: null,
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Learn for JLPT levle.',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    final emptyMono = PageResult<MonoFeedSummaryDto>(
      items: const [],
      nextCursor: null,
      hasMore: false,
      totalCount: 0,
    );
    await _pumpPublicProfile(
      tester,
      profile: profile,
      monoPage: emptyMono,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('publicProfileDisplayName')))
          .data,
      'Creator',
    );
    final nameTop = tester
        .getTopLeft(find.byKey(const ValueKey('publicProfileDisplayName')))
        .dy;
    final bioTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileBio'))).dy;
    expect(bioTop, greaterThan(nameTop));
  });

  testWidgets('M17B-2: mono writer fills empty profile identity',
      (tester) async {
    const profile = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: null,
      username: null,
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'Learn for JLPT levle.',
      followersCount: 1,
      followingCount: 0,
      isFollowingByMe: false,
    );
    final page = PageResult<MonoFeedSummaryDto>(
      items: [
        _monoWriterPage(
          writerDisplayName: 'Baby Cooky',
          writerHandle: '@baby_cute',
        ),
      ],
      nextCursor: null,
      hasMore: false,
      totalCount: 1,
    );
    await _pumpPublicProfile(tester, profile: profile, monoPage: page);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('publicProfileDisplayName')))
          .data,
      'Baby Cooky',
    );
    expect(find.text('@baby_cute'), findsOneWidget);
    final nameTop = tester
        .getTopLeft(find.byKey(const ValueKey('publicProfileDisplayName')))
        .dy;
    final handleTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileHandle'))).dy;
    final bioTop =
        tester.getTopLeft(find.byKey(const ValueKey('publicProfileBio'))).dy;
    expect(handleTop, greaterThan(nameTop));
    expect(bioTop, greaterThan(handleTop));
  });
}
