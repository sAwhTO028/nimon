import 'dart:convert';

import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';

/// Parses [ValidationSeverity] from API strings (`blocking`, `warning`, …).
ValidationSeverity? validationSeverityFromApi(Object? raw) {
  if (raw is! String) return null;
  switch (raw.toLowerCase()) {
    case 'blocking':
      return ValidationSeverity.blocking;
    case 'warning':
      return ValidationSeverity.warning;
    case 'info':
      return ValidationSeverity.info;
    default:
      return null;
  }
}

Map<String, Object?>? _asStringKeyMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

ValidationIssue? validationIssueFromJsonMap(Map<String, Object?> m) {
  final code = m['code'];
  final field = m['field'];
  final messageKey = m['messageKey'];
  final severityRaw = m['severity'];
  if (code is! String ||
      field is! String ||
      messageKey is! String ||
      severityRaw == null) {
    return null;
  }
  final sev = validationSeverityFromApi(severityRaw);
  if (sev == null) return null;
  Map<String, Object?>? params;
  final p = m['params'];
  final pm = _asStringKeyMap(p);
  if (pm != null) {
    params = pm.map((k, v) => MapEntry(k, _normalizeParam(v)));
  }
  final source = m['source'];
  return ValidationIssue(
    code: code,
    field: field,
    messageKey: messageKey,
    severity: sev,
    params: params,
    source: source is String ? source : null,
  );
}

Object? _normalizeParam(Object? v) {
  if (v is num && v is! int) return v.toInt();
  return v;
}

/// Builds [ValidationIssue] list from JSON array; skips malformed rows.
List<ValidationIssue> validationIssuesFromJsonList(Object? raw) {
  if (raw is! List) return const [];
  final out = <ValidationIssue>[];
  for (final item in raw) {
    final m = _asStringKeyMap(item);
    if (m == null) continue;
    final issue = validationIssueFromJsonMap(m);
    if (issue != null) out.add(issue);
  }
  return out;
}

Map<String, Object?>? _decodeJsonObject(String body) {
  try {
    final decoded = jsonDecode(body.trim());
    final m = _asStringKeyMap(decoded);
    return m;
  } catch (_) {
    return null;
  }
}

String? _rootValidationMessage(Map<String, Object?> root) {
  final m = root['message'];
  if (m is String) return m;
  if (m is Map) {
    final inner = m['message'];
    if (inner is String) return inner;
  }
  return null;
}

List<dynamic>? _rootIssuesList(Map<String, Object?> root) {
  final direct = root['issues'];
  if (direct is List) return direct;
  final m = root['message'];
  if (m is Map && m['issues'] is List) return m['issues'] as List;
  return null;
}

/// When the HTTP body matches `{ message: 'validation_failed', issues: [...] }`,
/// returns the parsed issues; otherwise null.
List<ValidationIssue>? tryParseValidationIssuesFromHttpBody(String body) {
  final root = _decodeJsonObject(body);
  if (root == null) return null;
  final msg = _rootValidationMessage(root);
  if (msg != 'validation_failed') return null;
  final list = _rootIssuesList(root);
  if (list == null) return null;
  return validationIssuesFromJsonList(list);
}
