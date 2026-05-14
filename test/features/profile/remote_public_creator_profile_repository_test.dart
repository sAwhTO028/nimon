import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';

void main() {
  test(
      'fetchPublicCreatorProfile hits /v1/users/:id/public-profile with optional auth',
      () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'userId': 'u1',
          'handle': '@h',
          'displayName': 'D',
          'avatarUrl': null,
          'coverImageUrl': 'https://cover.example/b.png',
          'bio': null,
          'followersCount': 2,
          'followingCount': 3,
          'isFollowingByMe': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemotePublicCreatorProfileRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
    );

    final out = await repo.fetchPublicCreatorProfile('u1');
    expect(captured!.url.path, '/v1/users/u1/public-profile');
    expect(captured!.headers['Authorization'], 'Bearer t');
    expect(out.userId, 'u1');
    expect(out.isFollowingByMe, true);
    expect(out.followersCount, 2);
  });

  test('fetchCreatorMonoPage hits /v1/mono/feed with writerId param', () async {
    http.BaseRequest? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'monoId': 'm1',
              'title': 'T',
              'coverUrl': null,
              'level': 'N5',
              'category': 'Love',
              'categories': <String>['Love'],
              'description': 'D',
              'writerId': 'u1',
              'writerHandle': '@h',
              'writerDisplayName': 'D',
              'writerAvatarUrl': 'https://avatars.test/z.png',
              'publishedAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-02T00:00:00.000Z',
              'likesCount': 0,
              'hasAudio': false,
              'isBookmarkedByMe': false,
              'myReaction': null,
              'shareUrl': null,
              'publishKind': '',
              'accessType': 'public',
            }
          ],
          'nextCursor': null,
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = RemotePublicCreatorProfileRepository(
      apiBaseUrl: 'http://127.0.0.1:9',
      client: client,
      authHeaderBuilder: () async => <String, String>{},
    );

    final page = await repo.fetchCreatorMonoPage('u1', cursor: 'c', limit: 7);
    expect(captured!.url.path, '/v1/mono/feed');
    expect(captured!.url.queryParameters['writerId'], 'u1');
    expect(page.items, hasLength(1));
    expect(page.items.single.writerId, 'u1');
  });

  test(
      'PublicCreatorProfile defaults effectiveDisplayName to handle or Creator',
      () {
    final p1 = PublicCreatorProfile.fromJson({
      'userId': 'u1',
      'handle': '@h',
      'displayName': null,
      'followersCount': 0,
      'followingCount': 0,
      'isFollowingByMe': false,
    });
    expect(p1.effectiveDisplayName, '@h');

    final p2 = PublicCreatorProfile.fromJson({
      'userId': 'u2',
    });
    expect(p2.effectiveDisplayName, 'Creator');
  });

  test('PublicCreatorProfile.fromJson nested profile and writer (M17B-2)', () {
    final nested = PublicCreatorProfile.fromJson({
      'userId': 'u1',
      'profile': {'display_name': 'Nested', 'handle': 'nh'},
      'followersCount': 0,
      'followingCount': 0,
      'isFollowingByMe': false,
    });
    expect(nested.displayName, 'Nested');
    expect(nested.handle, 'nh');

    final writer = PublicCreatorProfile.fromJson({
      'userId': 'u2',
      'writer': {'writerDisplayName': 'W', 'writerHandle': '@w'},
      'followersCount': 0,
      'followingCount': 0,
      'isFollowingByMe': false,
    });
    expect(writer.displayName, 'W');
    expect(writer.handle, '@w');
  });

  test('applyMonoWriterIdentityFallback copies feed writer fields', () {
    const base = PublicCreatorProfile(
      userId: 'u1',
      handle: null,
      displayName: null,
      username: null,
      avatarUrl: null,
      coverImageUrl: null,
      bio: 'b',
      followersCount: 0,
      followingCount: 0,
      isFollowingByMe: false,
    );
    final m = applyMonoWriterIdentityFallback(
      base,
      monoWriterId: 'u1',
      monoWriterName: 'From Feed',
      monoWriterHandle: '@feed',
    );
    expect(m.displayName, 'From Feed');
    expect(m.handle, '@feed');
  });
}
