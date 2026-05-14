import 'package:http/http.dart' as http;
import 'package:nimon/features/auth/auth_refresh_401_coordinator.dart';

/// Optional hook injected into repositories for central **401 → refresh → retry once**.
typedef NimonSendWithAuth401Recovery = Future<http.Response> Function({
  required Uri requestUri,
  required Future<Map<String, String>> Function() mergeHeaders,
  required Future<http.Response> Function(Map<String, String> headers) send,
  bool skip401Recovery,
  bool requireAuthHeaderForRecovery,
});

/// When `recovery` is null, sends once with [mergeHeaders] (no refresh logic).
Future<http.Response> nimonSendWithOptional401Recovery(
  NimonSendWithAuth401Recovery? recovery, {
  required Uri requestUri,
  required Future<Map<String, String>> Function() mergeHeaders,
  required Future<http.Response> Function(Map<String, String> headers) send,
  bool skip401Recovery = false,
  bool requireAuthHeaderForRecovery = true,
}) async {
  final w = recovery;
  if (w != null) {
    return w(
      requestUri: requestUri,
      mergeHeaders: mergeHeaders,
      send: send,
      skip401Recovery: skip401Recovery,
      requireAuthHeaderForRecovery: requireAuthHeaderForRecovery,
    );
  }
  return send(await mergeHeaders());
}

bool nimonUriShouldSkip401RefreshRetry(Uri uri) {
  final segments = uri.pathSegments;
  final i = segments.indexOf('auth');
  if (i <= 0 || i >= segments.length) return false;
  if (segments[i - 1] != 'v1') return false;
  if (i + 1 >= segments.length) return false;
  final action = segments[i + 1];
  return action == 'login' ||
      action == 'register' ||
      action == 'refresh' ||
      action == 'logout';
}

bool nimonHeadersHaveBearerAuth(Map<String, String> headers) {
  for (final e in headers.entries) {
    if (e.key.toLowerCase() != 'authorization') continue;
    final v = e.value.trim().toLowerCase();
    return v.startsWith('bearer ') && v.length > 'bearer '.length;
  }
  return false;
}

class AuthenticatedHttp {
  /// Sends [send], and on **401** optionally runs [coordinator] refresh once then
  /// retries [send] exactly once with freshly merged headers.
  ///
  /// Second attempt is the "retried after refresh" leg: refresh is never invoked
  /// again from this call path (no infinite loop).
  static Future<http.Response> sendWith401Recovery({
    required AuthRefresh401Coordinator coordinator,
    required Uri requestUri,
    required Future<Map<String, String>> Function() mergeHeaders,
    required Future<http.Response> Function(Map<String, String> headers) send,
    bool skip401Recovery = false,
    bool requireAuthHeaderForRecovery = true,
  }) async {
    var response = await send(await mergeHeaders());
    if (response.statusCode != 401) return response;
    if (skip401Recovery) return response;
    if (nimonUriShouldSkip401RefreshRetry(requestUri)) return response;

    final merged = await mergeHeaders();
    if (requireAuthHeaderForRecovery && !nimonHeadersHaveBearerAuth(merged)) {
      return response;
    }

    final recovered = await coordinator.tryRecoverAfterUnauthorized401();
    if (!recovered) return response;

    return send(await mergeHeaders());
  }
}

NimonSendWithAuth401Recovery nimonSendWithAuth401RecoveryFromCoordinator(
  AuthRefresh401Coordinator coordinator,
) {
  return ({
    required Uri requestUri,
    required Future<Map<String, String>> Function() mergeHeaders,
    required Future<http.Response> Function(Map<String, String> headers) send,
    bool skip401Recovery = false,
    bool requireAuthHeaderForRecovery = true,
  }) =>
      AuthenticatedHttp.sendWith401Recovery(
        coordinator: coordinator,
        requestUri: requestUri,
        mergeHeaders: mergeHeaders,
        send: send,
        skip401Recovery: skip401Recovery,
        requireAuthHeaderForRecovery: requireAuthHeaderForRecovery,
      );
}
