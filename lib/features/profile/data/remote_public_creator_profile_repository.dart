import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';

typedef OptionalAuthHeaderBuilder = Future<Map<String, String>> Function();

class RemotePublicCreatorProfileRepository {
  RemotePublicCreatorProfileRepository({
    required String apiBaseUrl,
    required OptionalAuthHeaderBuilder authHeaderBuilder,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _authHeaderBuilder = authHeaderBuilder,
        _client = client ?? http.Client();

  final String _apiBaseUrl;
  final OptionalAuthHeaderBuilder _authHeaderBuilder;
  final http.Client _client;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _mergeOptionalAuth(
    Map<String, String> headers,
  ) async {
    final auth = await _authHeaderBuilder();
    if (auth.isEmpty) return headers;
    return {...auth, ...headers};
  }

  Map<String, Object?> _jsonObjectFromResponse(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
  }

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 404) {
      throw StateError('Creator not found.');
    }
    final msg = r.body.trim().isEmpty
        ? 'HTTP ${r.statusCode}'
        : 'HTTP ${r.statusCode}: ${r.body}';
    throw StateError(msg);
  }

  static String? _optStr(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  static int _readInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static Map<String, Object?>? _mapLayer(Object? v) {
    if (v is! Map) return null;
    return Map<String, Object?>.from(
      v.map((k, val) => MapEntry(k.toString(), val)),
    );
  }

  /// Shallow identity fields from one JSON object (camelCase, snake_case, or
  /// common aliases). Used for public-profile and optional nested maps.
  static ({
    String? displayName,
    String? handle,
    String? username,
    String? bio,
  }) _identityStringsFromMap(Map<String, Object?> m) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final s = _optStr(m[k]);
        if (s != null) return s;
      }
      return null;
    }

    return (
      displayName: pick(const [
        'displayName',
        'display_name',
        'name',
        'fullName',
        'full_name',
        'writerDisplayName',
        'writer_display_name',
      ]),
      handle: pick(const [
        'handle',
        'userHandle',
        'user_handle',
        'creatorHandle',
        'creator_handle',
        'writerHandle',
        'writer_handle',
      ]),
      username: pick(const [
        'username',
        'userName',
        'user_name',
        'login',
      ]),
      bio: pick(const [
        'bio',
        'biography',
        'about',
      ]),
    );
  }

  static ({
    String? displayName,
    String? handle,
    String? username,
    String? bio,
  }) _mergeIdentityLayers(
    ({
      String? displayName,
      String? handle,
      String? username,
      String? bio,
    }) a,
    ({
      String? displayName,
      String? handle,
      String? username,
      String? bio,
    }) b,
  ) {
    return (
      displayName: a.displayName ?? b.displayName,
      handle: a.handle ?? b.handle,
      username: a.username ?? b.username,
      bio: a.bio ?? b.bio,
    );
  }

  Future<PublicCreatorProfile> fetchPublicCreatorProfile(String userId) async {
    final rid = userId.trim();
    if (rid.isEmpty) throw ArgumentError('userId is empty');
    final uri = _u('/v1/users/$rid/public-profile');
    if (kDebugMode) {
      debugPrint(
        'RemotePublicCreatorProfileRepository.fetchPublicCreatorProfile: GET $uri',
      );
    }
    final resp = await _client.get(
      uri,
      headers: await _mergeOptionalAuth({'Accept': 'application/json'}),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final out = PublicCreatorProfile.fromJson(m);
    if (kDebugMode) {
      debugPrint(
        '[public-profile-identity] userId=${out.userId} displayName=${out.displayName} '
        'handle=${out.handle} username=${out.username} bioLen=${(out.bio ?? '').length}',
      );
    }
    return out;
  }

  Future<PageResult<MonoFeedSummaryDto>> fetchCreatorMonoPage(
    String userId, {
    String? cursor,
    int? limit,
  }) async {
    final rid = userId.trim();
    if (rid.isEmpty) throw ArgumentError('userId is empty');
    final req = PageRequest(
      cursor: cursor,
      limit: limit ?? 15,
      sort: 'recent',
    );
    final qp = {
      ...req.toQueryParameters(),
      'writerId': rid,
    };
    final uri = _u('/v1/mono/feed').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint(
        'RemotePublicCreatorProfileRepository.fetchCreatorMonoPage: GET $uri',
      );
    }
    final resp = await _client.get(
      uri,
      headers: await _mergeOptionalAuth({'Accept': 'application/json'}),
    );
    _throwIfNotOk(resp);
    final m = _jsonObjectFromResponse(resp);
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MonoFeedSummaryDto>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(MonoFeedSummaryDto.fromJson(it));
    }
    final nextCursor = _optStr(m['nextCursor']);
    final hasMore = m['hasMore'] is bool ? m['hasMore'] as bool : false;
    return PageResult<MonoFeedSummaryDto>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: null,
    );
  }
}

class PublicCreatorProfile {
  const PublicCreatorProfile({
    required this.userId,
    required this.handle,
    required this.displayName,
    this.username,
    required this.avatarUrl,
    required this.coverImageUrl,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowingByMe,
  });

  final String userId;
  final String? handle;
  final String? displayName;

  /// Optional login/username when the API includes it (V1 public-profile DTO
  /// may omit this; parsed defensively for forward compatibility).
  final String? username;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final bool isFollowingByMe;

  String get effectiveDisplayName {
    final dn = (displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;
    final h = (handle ?? '').trim();
    if (h.isNotEmpty) return h;
    return 'Creator';
  }

  /// Public header primary line: display name → username → handle → Creator.
  String get publicProfileMainDisplayName {
    String? nz(String? s) {
      final t = (s ?? '').trim();
      return t.isEmpty ? null : t;
    }

    return nz(displayName) ?? nz(username) ?? nz(handle) ?? 'Creator';
  }

  /// `@handle` second line when it adds information beyond [mainDisplayName].
  String? publicProfileSecondaryHandleLine(String mainDisplayName) {
    String? nz(String? s) {
      final t = (s ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final preferred = nz(handle) ?? nz(username);
    if (preferred == null) return null;
    var core = preferred.startsWith('@') ? preferred.substring(1) : preferred;
    core = core.trim();
    if (core.isEmpty) return null;
    final atForm = '@$core';
    final main = mainDisplayName.trim();
    if (atForm == main) return null;
    return atForm;
  }

  /// Writer handle for navigation (collections detail, etc.).
  String publicProfileWriterHandleLabel(String mainDisplayName) {
    final secondary = publicProfileSecondaryHandleLine(mainDisplayName);
    if (secondary != null) return secondary;
    String? nz(String? s) {
      final t = (s ?? '').trim();
      return t.isEmpty ? null : t;
    }

    final h = nz(handle);
    if (h != null) {
      final c = (h.startsWith('@') ? h.substring(1) : h).trim();
      if (c.isEmpty) return '@reader';
      return '@$c';
    }
    final u = nz(username);
    if (u != null) {
      final c = (u.startsWith('@') ? u.substring(1) : u).trim();
      if (c.isEmpty) return '@reader';
      return '@$c';
    }
    return '@reader';
  }

  factory PublicCreatorProfile.fromJson(Map<String, Object?> json) {
    final uidRaw =
        RemotePublicCreatorProfileRepository._optStr(json['userId']) ??
            RemotePublicCreatorProfileRepository._optStr(json['id']);
    final uid = (uidRaw ?? '').trim();
    final isFollowing = json['isFollowingByMe'] is bool
        ? json['isFollowingByMe'] as bool
        : false;

    var merged = RemotePublicCreatorProfileRepository._identityStringsFromMap(
      json,
    );
    for (final layer in [
      RemotePublicCreatorProfileRepository._mapLayer(json['profile']),
      RemotePublicCreatorProfileRepository._mapLayer(json['writer']),
      RemotePublicCreatorProfileRepository._mapLayer(json['user']),
    ]) {
      if (layer == null) continue;
      merged = RemotePublicCreatorProfileRepository._mergeIdentityLayers(
        merged,
        RemotePublicCreatorProfileRepository._identityStringsFromMap(layer),
      );
      final userProfile =
          RemotePublicCreatorProfileRepository._mapLayer(layer['profile']);
      if (userProfile != null) {
        merged = RemotePublicCreatorProfileRepository._mergeIdentityLayers(
          merged,
          RemotePublicCreatorProfileRepository._identityStringsFromMap(
            userProfile,
          ),
        );
      }
    }

    return PublicCreatorProfile(
      userId: uid,
      handle: merged.handle,
      displayName: merged.displayName,
      username: merged.username,
      avatarUrl:
          RemotePublicCreatorProfileRepository._optStr(json['avatarUrl']) ??
              RemotePublicCreatorProfileRepository._optStr(
                RemotePublicCreatorProfileRepository._mapLayer(
                    json['profile'])?['avatarUrl'],
              ) ??
              RemotePublicCreatorProfileRepository._optStr(
                RemotePublicCreatorProfileRepository._mapLayer(
                    json['user'])?['avatarUrl'],
              ),
      coverImageUrl:
          RemotePublicCreatorProfileRepository._optStr(json['coverImageUrl']),
      bio: merged.bio,
      followersCount:
          RemotePublicCreatorProfileRepository._readInt(json['followersCount']),
      followingCount:
          RemotePublicCreatorProfileRepository._readInt(json['followingCount']),
      isFollowingByMe: isFollowing,
    );
  }
}

/// Fills missing [PublicCreatorProfile.displayName] / [PublicCreatorProfile.handle]
/// from the first mono row when `GET /v1/mono/feed?writerId=` still carries
/// `writerDisplayName` / `writerHandle` (M17B-2: public-profile contract gaps).
PublicCreatorProfile applyMonoWriterIdentityFallback(
  PublicCreatorProfile profile, {
  required String? monoWriterId,
  required String monoWriterName,
  required String monoWriterHandle,
}) {
  final pid = profile.userId.trim();
  final mid = (monoWriterId ?? '').trim();
  if (mid.isNotEmpty && mid != pid) {
    return profile;
  }

  final hasDn = (profile.displayName ?? '').trim().isNotEmpty;
  final hasHandle = (profile.handle ?? '').trim().isNotEmpty;
  if (hasDn && hasHandle) {
    return profile;
  }

  final wn = monoWriterName.trim();
  final wh = monoWriterHandle.trim();
  final newDn =
      hasDn ? profile.displayName : (wn.isNotEmpty ? wn : profile.displayName);
  final newH =
      hasHandle ? profile.handle : (wh.isNotEmpty ? wh : profile.handle);

  if (newDn == profile.displayName && newH == profile.handle) {
    return profile;
  }

  return PublicCreatorProfile(
    userId: profile.userId,
    handle: newH,
    displayName: newDn,
    username: profile.username,
    avatarUrl: profile.avatarUrl,
    coverImageUrl: profile.coverImageUrl,
    bio: profile.bio,
    followersCount: profile.followersCount,
    followingCount: profile.followingCount,
    isFollowingByMe: profile.isFollowingByMe,
  );
}
