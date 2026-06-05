import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

typedef PreferencesAuthHeaderBuilder = Future<Map<String, String>> Function();

class UserPreferences {
  const UserPreferences({
    required this.appLocale,
    required this.contentLocale,
    required this.learningLanguage,
    required this.themeMode,
    required this.readingTextSize,
    required this.showExplanations,
  });

  final String appLocale; // system|en|ja|my
  final String contentLocale; // en|my|ja
  final String learningLanguage; // ja | en
  final String themeMode; // system|light|dark
  final String readingTextSize; // small|standard|large
  final bool showExplanations;

  static const defaults = UserPreferences(
    appLocale: 'system',
    contentLocale: 'en',
    learningLanguage: 'ja',
    themeMode: 'system',
    readingTextSize: 'standard',
    showExplanations: true,
  );

  UserPreferences copyWith({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  }) {
    return UserPreferences(
      appLocale: appLocale ?? this.appLocale,
      contentLocale: contentLocale ?? this.contentLocale,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      themeMode: themeMode ?? this.themeMode,
      readingTextSize: readingTextSize ?? this.readingTextSize,
      showExplanations: showExplanations ?? this.showExplanations,
    );
  }
}

abstract class UserPreferencesRepository {
  Future<UserPreferences> fetchPreferences();

  Future<UserPreferences> patchPreferences({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  });
}

Map<String, Object?> _tryDecodeObject(String body) {
  final t = body.trim();
  if (t.isEmpty) return <String, Object?>{};
  final decoded = jsonDecode(t);
  if (decoded is Map<String, dynamic>) {
    return Map<String, Object?>.from(decoded);
  }
  throw StateError('Expected JSON object response');
}

String _optStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}

bool _parseBool(Object? v, bool fallback) {
  if (v == null) return fallback;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

UserPreferences _parsePreferences(Map<String, Object?> m) {
  String pick(String key, String fallback) {
    final t = _optStr(m[key]);
    return t.isEmpty ? fallback : t;
  }

  final rawContentLocale = pick(
    'contentLocale',
    UserPreferences.defaults.contentLocale,
  );
  final contentLocale = normalizeContentLocaleWireCode(rawContentLocale) ??
      UserPreferences.defaults.contentLocale;

  return UserPreferences(
    appLocale: pick('appLocale', UserPreferences.defaults.appLocale),
    contentLocale: contentLocale,
    learningLanguage: safeLearningLanguageWireCode(
      pick('learningLanguage', UserPreferences.defaults.learningLanguage),
    ),
    themeMode: pick('themeMode', UserPreferences.defaults.themeMode),
    readingTextSize:
        pick('readingTextSize', UserPreferences.defaults.readingTextSize),
    showExplanations: _parseBool(
        m['showExplanations'], UserPreferences.defaults.showExplanations),
  );
}

class RemoteUserPreferencesRepository implements UserPreferencesRepository {
  RemoteUserPreferencesRepository({
    required String apiBaseUrl,
    http.Client? client,
    required PreferencesAuthHeaderBuilder authHeaderBuilder,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder,
        _sendWithAuth401 = sendWithAuth401Recovery;

  final String _apiBaseUrl;
  final http.Client _client;
  final PreferencesAuthHeaderBuilder _authHeaderBuilder;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;

  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _auth() async => await _authHeaderBuilder();

  Future<http.Response> _nimonAuthSend(
    Uri uri,
    Future<Map<String, String>> Function() mergeHeaders,
    Future<http.Response> Function(Map<String, String> headers) send,
  ) =>
      nimonSendWithOptional401Recovery(
        _sendWithAuth401,
        requestUri: uri,
        mergeHeaders: mergeHeaders,
        send: send,
      );

  Never _throwMapped(http.Response r, {required String fallback}) {
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
    if (kDebugMode) {
      debugPrint(
        'RemoteUserPreferencesRepository: HTTP ${r.statusCode} ${r.request?.url}\n${r.body}',
      );
    }
    if (r.statusCode == 401) {
      throw StateError('Sign in required.');
    }
    throw StateError(fallback);
  }

  void _ensure2xx(http.Response r, {required String fallback}) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    _throwMapped(r, fallback: fallback);
  }

  @override
  Future<UserPreferences> fetchPreferences() async {
    try {
      final uri = _u('/v1/me/preferences');
      if (kDebugMode) debugPrint('RemoteUserPreferencesRepository: GET $uri');
      final resp = await _nimonAuthSend(
        uri,
        () async => <String, String>{
          ...await _auth(),
          'Accept': 'application/json',
        },
        (h) => _client.get(uri, headers: h),
      );
      _ensure2xx(resp, fallback: 'Could not load preferences.');
      return _parsePreferences(_tryDecodeObject(resp.body));
    } catch (e, st) {
      if (kDebugMode) debugPrint('fetchPreferences error: $e\n$st');
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not load preferences.');
    }
  }

  @override
  Future<UserPreferences> patchPreferences({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  }) async {
    try {
      final uri = _u('/v1/me/preferences');
      if (kDebugMode) debugPrint('RemoteUserPreferencesRepository: PATCH $uri');
      final body = <String, Object?>{
        if (appLocale != null) 'appLocale': appLocale,
        if (contentLocale != null) 'contentLocale': contentLocale,
        if (learningLanguage != null) 'learningLanguage': learningLanguage,
        if (themeMode != null) 'themeMode': themeMode,
        if (readingTextSize != null) 'readingTextSize': readingTextSize,
        if (showExplanations != null) 'showExplanations': showExplanations,
      };
      final resp = await _nimonAuthSend(
        uri,
        () async => <String, String>{
          ...await _auth(),
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        (h) => _client.patch(uri, headers: h, body: jsonEncode(body)),
      );
      _ensure2xx(resp, fallback: 'Could not save preferences.');
      return _parsePreferences(_tryDecodeObject(resp.body));
    } catch (e, st) {
      if (kDebugMode) debugPrint('patchPreferences error: $e\n$st');
      if (_strict) rethrow;
      if (e is StateError) rethrow;
      throw StateError('Could not save preferences.');
    }
  }
}
