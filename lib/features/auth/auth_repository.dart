import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

const String _kFriendlyNetworkMessage =
    'Cannot connect to server. Please check that the backend is running.';

class AuthRepositoryException implements Exception {
  AuthRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthRepositoryException($statusCode): $message';
}

/// HTTP client for `/v1/auth/*` and `/v1/me`.
class AuthRepository {
  AuthRepository({
    required String apiBaseUrl,
    http.Client? httpClient,
  })  : _base = apiBaseUrl.replaceAll(RegExp(r'\/+$'), ''),
        _client = httpClient ?? http.Client();

  final String _base;
  final http.Client _client;

  Uri _u(String path) => Uri.parse('$_base$path');

  bool _isConnectivityFailure(Object e) {
    if (e is SocketException) return true;
    if (e is http.ClientException) return true;
    final s = e.toString();
    return s.contains('ClientException') ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('HandshakeException');
  }

  Future<T> _withFriendlyNetwork<T>(Future<T> Function() run, String op) async {
    try {
      return await run();
    } catch (e, st) {
      if (_isConnectivityFailure(e)) {
        if (kDebugMode) {
          debugPrint(
            '[AuthRepository] $op connectivity failure: ${e.runtimeType}',
          );
          debugPrint(
            '[AuthRepository] apiBase=${RemoteBackendConfig.apiBaseUrl}',
          );
        }
        throw AuthRepositoryException(_kFriendlyNetworkMessage);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Map<String, Object?> _decodeObject(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw AuthRepositoryException('Expected JSON object',
        statusCode: r.statusCode);
  }

  void _throwIfNotOk(http.Response r, {String? context}) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    final msg = r.body.trim().isEmpty
        ? (context ?? 'HTTP ${r.statusCode}')
        : r.body.trim();
    throw AuthRepositoryException(msg, statusCode: r.statusCode);
  }

  AuthTokens _tokensFromJson(Map<String, Object?> m) {
    final access = m['accessToken'];
    final refresh = m['refreshToken'];
    if (access is! String || access.trim().isEmpty) {
      throw AuthRepositoryException('Missing accessToken');
    }
    if (refresh is! String || refresh.trim().isEmpty) {
      throw AuthRepositoryException('Missing refreshToken');
    }
    final tt = m['tokenType'];
    return AuthTokens(
      accessToken: access.trim(),
      refreshToken: refresh.trim(),
      tokenType: tt is String ? tt : 'Bearer',
    );
  }

  Future<AuthTokens> register({
    required String email,
    required String password,
  }) async {
    return _withFriendlyNetwork(() async {
      final resp = await _client.post(
        _u('/v1/auth/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      _throwIfNotOk(resp, context: 'register failed');
      return _tokensFromJson(_decodeObject(resp));
    }, 'register');
  }

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    return _withFriendlyNetwork(() async {
      final resp = await _client.post(
        _u('/v1/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      _throwIfNotOk(resp, context: 'login failed');
      return _tokensFromJson(_decodeObject(resp));
    }, 'login');
  }

  Future<AuthTokens> refresh({required String refreshToken}) async {
    return _withFriendlyNetwork(() async {
      final resp = await _client.post(
        _u('/v1/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      _throwIfNotOk(resp, context: 'refresh failed');
      return _tokensFromJson(_decodeObject(resp));
    }, 'refresh');
  }

  Future<void> logout({required String refreshToken}) async {
    await _withFriendlyNetwork(() async {
      final resp = await _client.post(
        _u('/v1/auth/logout'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (resp.statusCode == 204 || resp.statusCode == 200) return;
      _throwIfNotOk(resp, context: 'logout failed');
    }, 'logout');
  }

  Future<AuthUser> getMe({required String accessToken}) async {
    return _withFriendlyNetwork(() async {
      final resp = await _client.get(
        _u('/v1/me'),
        headers: {
          'Authorization': 'Bearer ${accessToken.trim()}',
          'Accept': 'application/json',
        },
      );
      _throwIfNotOk(resp, context: 'getMe failed');
      final m = _decodeObject(resp);
      final userRaw = m['user'];
      if (userRaw is! Map) {
        throw AuthRepositoryException('getMe: missing user');
      }
      final userMap = Map<String, Object?>.from(
        userRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final id = userMap['id'];
      if (id is! String || id.trim().isEmpty) {
        throw AuthRepositoryException('getMe: missing user.id');
      }
      final profileRaw = m['profile'];
      String? displayName;
      String? handle;
      if (profileRaw is Map) {
        final pm = Map<String, Object?>.from(
          profileRaw.map((k, v) => MapEntry(k.toString(), v)),
        );
        final dn = pm['displayName'];
        final h = pm['handle'];
        displayName = dn is String ? dn : null;
        handle = h is String ? h : null;
      }
      final email = userMap['email'];
      return AuthUser(
        id: id.trim(),
        email: email is String ? email : null,
        displayName: displayName,
        handle: handle,
      );
    }, 'getMe');
  }
}
