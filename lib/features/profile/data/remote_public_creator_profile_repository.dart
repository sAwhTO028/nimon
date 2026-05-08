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
    return PublicCreatorProfile.fromJson(m);
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

  factory PublicCreatorProfile.fromJson(Map<String, Object?> json) {
    final uid = (json['userId']?.toString() ?? '').trim();
    final isFollowing = json['isFollowingByMe'] is bool
        ? json['isFollowingByMe'] as bool
        : false;
    return PublicCreatorProfile(
      userId: uid,
      handle: RemotePublicCreatorProfileRepository._optStr(json['handle']),
      displayName:
          RemotePublicCreatorProfileRepository._optStr(json['displayName']),
      avatarUrl:
          RemotePublicCreatorProfileRepository._optStr(json['avatarUrl']),
      coverImageUrl:
          RemotePublicCreatorProfileRepository._optStr(json['coverImageUrl']),
      bio: RemotePublicCreatorProfileRepository._optStr(json['bio']),
      followersCount:
          RemotePublicCreatorProfileRepository._readInt(json['followersCount']),
      followingCount:
          RemotePublicCreatorProfileRepository._readInt(json['followingCount']),
      isFollowingByMe: isFollowing,
    );
  }
}
