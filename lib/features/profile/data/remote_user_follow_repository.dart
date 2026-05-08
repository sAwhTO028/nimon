import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';

typedef UserFollowAuthHeaderBuilder = Future<Map<String, String>> Function();

class RemoteUserFollowRepository {
  RemoteUserFollowRepository({
    required String apiBaseUrl,
    required UserFollowAuthHeaderBuilder authHeaderBuilder,
    http.Client? client,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _authHeaderBuilder = authHeaderBuilder,
        _client = client ?? http.Client();

  final String _apiBaseUrl;
  final UserFollowAuthHeaderBuilder _authHeaderBuilder;
  final http.Client _client;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Map<String, Object?> _jsonObjectFromResponse(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
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

  Future<Map<String, String>> _authHeadersOrThrow() async {
    final h = await _authHeaderBuilder();
    if (h.isEmpty) {
      throw StateError('Sign in required.');
    }
    return h;
  }

  /// Accept / optional Bearer — used for public GET endpoints.
  Future<Map<String, String>> _acceptHeadersOptionalAuth() async {
    final h = await _authHeaderBuilder();
    return {
      'Accept': 'application/json',
      ...h,
    };
  }

  Never _mapHttpError(http.Response r) {
    final raw = r.body.trim();
    if (r.statusCode == 401) {
      throw StateError('Sign in required.');
    }
    if (r.statusCode == 404) {
      throw StateError('User not found.');
    }
    if (r.statusCode == 400) {
      if (raw.contains('cannot_follow_self')) {
        throw StateError('You can’t follow yourself.');
      }
    }
    final msg =
        raw.isEmpty ? 'HTTP ${r.statusCode}' : 'HTTP ${r.statusCode}: $raw';
    throw StateError(msg);
  }

  Future<FollowState> followUser(String userId) async {
    final rid = userId.trim();
    if (rid.isEmpty) throw ArgumentError('userId is empty');
    final uri = _u('/v1/users/$rid/follow');
    if (kDebugMode) {
      debugPrint('RemoteUserFollowRepository.followUser: POST $uri');
    }
    final resp = await _client.post(
      uri,
      headers: {
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) _mapHttpError(resp);
    final m = _jsonObjectFromResponse(resp);
    return FollowState.fromJson(m);
  }

  Future<FollowState> unfollowUser(String userId) async {
    final rid = userId.trim();
    if (rid.isEmpty) throw ArgumentError('userId is empty');
    final uri = _u('/v1/users/$rid/follow');
    if (kDebugMode) {
      debugPrint('RemoteUserFollowRepository.unfollowUser: DELETE $uri');
    }
    final resp = await _client.delete(
      uri,
      headers: {
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) _mapHttpError(resp);
    final m = _jsonObjectFromResponse(resp);
    return FollowState.fromJson(m);
  }

  Future<PageResult<MeFollowingUser>> fetchFollowingPage(
    PageRequest request, {
    int? limit,
  }) async {
    final effective = PageRequest(
      cursor: request.cursor,
      limit: limit ?? request.limit,
      sort: request.sort,
    );
    final qp = effective.toQueryParameters();
    final uri = _u('/v1/me/following').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint('RemoteUserFollowRepository.fetchFollowingPage: GET $uri');
    }
    final resp = await _client.get(
      uri,
      headers: {
        ...await _authHeadersOrThrow(),
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) _mapHttpError(resp);
    final m = _jsonObjectFromResponse(resp);
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MeFollowingUser>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(MeFollowingUser.fromJson(it));
    }
    final nextCursor = _optStr(m['nextCursor']);
    final hasMore = m['hasMore'] is bool ? m['hasMore'] as bool : false;
    return PageResult<MeFollowingUser>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: null,
    );
  }

  /// Public list: followers of [targetUserId] (`GET /v1/users/:id/followers`).
  Future<PageResult<MeFollowingUser>> fetchFollowersPage(
    String targetUserId,
    PageRequest request, {
    int? limit,
  }) async {
    final rid = targetUserId.trim();
    if (rid.isEmpty) {
      throw ArgumentError('targetUserId is empty');
    }
    final enc = Uri.encodeComponent(rid);
    final effective = PageRequest(
      cursor: request.cursor,
      limit: limit ?? request.limit,
      sort: request.sort,
    );
    final qp = effective.toQueryParameters();
    final uri = _u('/v1/users/$enc/followers').replace(queryParameters: qp);
    if (kDebugMode) {
      debugPrint('RemoteUserFollowRepository.fetchFollowersPage: GET $uri');
    }
    final resp = await _client.get(
      uri,
      headers: await _acceptHeadersOptionalAuth(),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      _mapHttpError(resp);
    }
    final m = _jsonObjectFromResponse(resp);
    final rawItems = (m['items'] as List?) ?? const [];
    final items = <MeFollowingUser>[];
    for (final x in rawItems) {
      if (x is! Map) continue;
      final it = Map<String, Object?>.from(
        x.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(MeFollowingUser.fromJson(it));
    }
    final nextCursor = _optStr(m['nextCursor']);
    final hasMore = m['hasMore'] is bool ? m['hasMore'] as bool : false;
    return PageResult<MeFollowingUser>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: null,
    );
  }
}

class FollowState {
  const FollowState({
    required this.userId,
    required this.isFollowing,
    required this.followersCount,
    required this.followingCount,
  });

  final String userId;
  final bool isFollowing;
  final int followersCount;
  final int followingCount;

  factory FollowState.fromJson(Map<String, Object?> json) {
    final uid = (json['userId']?.toString() ?? '').trim();
    final isFollowing =
        json['isFollowing'] is bool ? json['isFollowing'] as bool : false;
    return FollowState(
      userId: uid,
      isFollowing: isFollowing,
      followersCount:
          RemoteUserFollowRepository._readInt(json['followersCount']),
      followingCount:
          RemoteUserFollowRepository._readInt(json['followingCount']),
    );
  }
}

class MeFollowingUser {
  const MeFollowingUser({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.avatarUrl,
    required this.followedAt,
  });

  final String userId;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;
  final String followedAt;

  factory MeFollowingUser.fromJson(Map<String, Object?> json) {
    final uid = (json['userId']?.toString() ?? '').trim();
    return MeFollowingUser(
      userId: uid,
      handle: RemoteUserFollowRepository._optStr(json['handle']),
      displayName: RemoteUserFollowRepository._optStr(json['displayName']),
      avatarUrl: RemoteUserFollowRepository._optStr(json['avatarUrl']),
      followedAt: (json['followedAt']?.toString() ?? '').trim(),
    );
  }
}
