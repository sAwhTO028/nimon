import 'dart:convert';

import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';

Map<String, Object?>? _asStringKeyMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

Map<String, Object?>? _decodeJsonObject(String body) {
  try {
    final decoded = jsonDecode(body.trim());
    return _asStringKeyMap(decoded);
  } catch (_) {
    return null;
  }
}

int _asInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

AppQuotaExceededException? _parseQuotaMap(Map<String, Object?> map) {
  final code = map['code'];
  if (code is! String || code.trim().toLowerCase() != 'quota_exceeded') {
    return null;
  }
  final key = map['key'];
  if (key is! String || key.trim().isEmpty) return null;
  return AppQuotaExceededException(
    key: key.trim(),
    limit: _asInt(map['limit']),
    current: _asInt(map['current']),
  );
}

/// Parses Nest `quota_exceeded` payloads from HTTP JSON bodies.
///
/// Supports:
/// - Root `{ "code": "quota_exceeded", "key", "limit", "current" }`
/// - Nested `{ "error": { ... same fields ... } }` (Nest-style envelopes)
/// - Nested `{ "message": { ... } }` (defensive)
AppQuotaExceededException? tryParseQuotaExceededFromHttpBody(String body) {
  final root = _decodeJsonObject(body);
  if (root == null) return null;

  final direct = _parseQuotaMap(root);
  if (direct != null) return direct;

  final err = root['error'];
  final errMap = _asStringKeyMap(err);
  if (errMap != null) {
    final nested = _parseQuotaMap(errMap);
    if (nested != null) return nested;
  }

  final msg = root['message'];
  final msgMap = _asStringKeyMap(msg);
  if (msgMap != null) {
    final nested = _parseQuotaMap(msgMap);
    if (nested != null) return nested;
  }

  return null;
}
