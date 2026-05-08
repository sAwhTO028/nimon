import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

typedef MeProfileAuthHeaderBuilder = Future<Map<String, String>> Function();

class EditableProfileResponse {
  const EditableProfileResponse({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.coverImageUrl,
    required this.bio,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String? bio;
}

abstract class MeProfileRepository {
  Future<EditableProfileResponse> fetchMyProfile();

  Future<EditableProfileResponse> patchMyProfile({
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? coverImageUrl,
    String? bio,
  });
}

Map<String, Object?>? _tryDecodeObject(String body) {
  final t = body.trim();
  if (t.isEmpty) return null;
  try {
    final decoded = jsonDecode(t);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {}
  return null;
}

void _logErrorIfDebug(http.Response r) {
  if (!kDebugMode) return;
  final url = r.request?.url;
  debugPrint('RemoteMeProfileRepository: HTTP ${r.statusCode} $url\n${r.body}');
}

bool _isHandleTakenConflict(Map<String, Object?>? m) {
  if (m == null) return false;
  final top = m['code']?.toString().trim();
  if (top == 'handle_taken') return true;
  final msg = m['message'];
  if (msg is Map) {
    final mm = Map<String, Object?>.from(
      msg.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (mm['code']?.toString().trim() == 'handle_taken') return true;
  }
  return false;
}

String? _firstStringFromMessageField(Object? messageField) {
  if (messageField == null) return null;
  if (messageField is String) {
    final t = messageField.trim();
    return t.isEmpty ? null : t;
  }
  if (messageField is List) {
    String? first;
    for (final item in messageField) {
      if (item is! String) continue;
      final t = item.trim();
      if (t.isEmpty) continue;
      first ??= t;
      final mapped = _mapProfileImageUrlValidation(t);
      if (mapped != t) return mapped;
    }
    return first;
  }
  if (messageField is Map) {
    final mm = Map<String, Object?>.from(
      messageField.map((k, v) => MapEntry(k.toString(), v)),
    );
    final inner = mm['message'];
    if (inner is String) {
      final t = inner.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

String _mapProfileImageUrlValidation(String raw) {
  final lower = raw.toLowerCase();
  final looksLikeUrlField = lower.contains('avatarurl') ||
      lower.contains('coverimageurl') ||
      lower.contains('cover image') ||
      lower.contains('avatar url');
  final looksLikeUrlRule = lower.contains('url') ||
      lower.contains('http') ||
      lower.contains('protocol');
  if (looksLikeUrlField && looksLikeUrlRule) {
    return 'Profile image URL is invalid.';
  }
  return raw;
}

String? _userFacingMessageFromErrorBody(http.Response r) {
  final m = _tryDecodeObject(r.body);
  if (m == null) return null;
  final fromMsg = _firstStringFromMessageField(m['message']);
  if (fromMsg != null) return _mapProfileImageUrlValidation(fromMsg);
  return null;
}

class RemoteMeProfileRepository implements MeProfileRepository {
  RemoteMeProfileRepository({
    required String apiBaseUrl,
    http.Client? client,
    required MeProfileAuthHeaderBuilder authHeaderBuilder,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder;

  final String _apiBaseUrl;
  final http.Client _client;
  final MeProfileAuthHeaderBuilder _authHeaderBuilder;

  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _auth() async => await _authHeaderBuilder();

  Map<String, Object?> _jsonObject(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
  }

  Never _throwMapped(http.Response r, {required String fallback}) {
    notifyIfStrictUnauthorized401(r);
    _logErrorIfDebug(r);

    if (r.statusCode == 401) {
      throw StateError('Sign in required.');
    }

    final m = _tryDecodeObject(r.body);
    if (r.statusCode == 409 && _isHandleTakenConflict(m)) {
      throw StateError('That handle is taken.');
    }

    final userMsg = _userFacingMessageFromErrorBody(r);
    if (userMsg != null && userMsg.length <= 320 && !userMsg.contains('\n')) {
      throw StateError(userMsg);
    }

    throw StateError(fallback);
  }

  void _ensure2xx(http.Response r, {required String fallback}) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    _throwMapped(r, fallback: fallback);
  }

  EditableProfileResponse _parseProfileEnvelope(Map<String, Object?> m) {
    final user = m['user'];
    if (user is! Map) throw StateError('Missing user.');
    final um = Map<String, Object?>.from(
      user.map((k, v) => MapEntry(k.toString(), v)),
    );
    final profile = m['profile'];
    Map<String, Object?> pm = const {};
    if (profile is Map) {
      pm = Map<String, Object?>.from(
        profile.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    final id = (um['id'] ?? '').toString().trim();
    if (id.isEmpty) throw StateError('Missing user id.');

    String? optStr(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return EditableProfileResponse(
      userId: id,
      email: optStr(um['email']),
      displayName: optStr(pm['displayName']),
      handle: optStr(pm['handle']),
      avatarUrl: optStr(pm['avatarUrl']),
      coverImageUrl: optStr(pm['coverImageUrl']),
      bio: optStr(pm['bio']),
    );
  }

  @override
  Future<EditableProfileResponse> fetchMyProfile() async {
    try {
      final uri = _u('/v1/me/profile');
      if (kDebugMode) debugPrint('RemoteMeProfileRepository: GET $uri');
      final resp = await _client.get(
        uri,
        headers: {
          ...await _auth(),
          'Accept': 'application/json',
        },
      );
      _ensure2xx(resp, fallback: 'Could not load profile.');
      return _parseProfileEnvelope(_jsonObject(resp));
    } catch (e, st) {
      if (kDebugMode) debugPrint('fetchMyProfile error: $e\n$st');
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load profile.');
    }
  }

  @override
  Future<EditableProfileResponse> patchMyProfile({
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? coverImageUrl,
    String? bio,
  }) async {
    try {
      final uri = _u('/v1/me/profile');
      if (kDebugMode) debugPrint('RemoteMeProfileRepository: PATCH $uri');
      final body = <String, Object?>{
        if (displayName != null) 'displayName': displayName,
        if (handle != null) 'handle': handle,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (bio != null) 'bio': bio,
      };
      final resp = await _client.patch(
        uri,
        headers: {
          ...await _auth(),
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      _ensure2xx(
        resp,
        fallback: 'Could not save profile. Please try again.',
      );
      return _parseProfileEnvelope(_jsonObject(resp));
    } on StateError {
      rethrow;
    } catch (e, st) {
      if (kDebugMode) debugPrint('patchMyProfile error: $e\n$st');
      if (_strict) rethrow;
      throw StateError('Could not save profile. Please try again.');
    }
  }
}
