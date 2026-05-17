import 'package:flutter/foundation.dart';

import 'package:nimon/features/create/data/remote_backend_config.dart';

/// Resolves a **public web** URL for sharing a creator profile (M17M).
///
/// Priority:
/// 1. [explicitUrl] when non-empty (e.g. future API field).
/// 2. `{NIMON_PUBLIC_WEB_BASE_URL}/u/{slug}` with slug from [handle] (without `@`)
///    or [userId] if handle is empty.
/// 3. Same path on a **non-loopback** [apiBaseUrl] (LAN dev), mirroring mono share rules.
///
/// Returns empty when only loopback origins would be used (same policy as mono shares).
@visibleForTesting
String resolvePublicProfileShareUrl({
  String? explicitUrl,
  String? userId,
  String? handle,
  String? publicWebBaseFromDefine,
  String? apiBaseFromDefine,
}) {
  final ex = (explicitUrl ?? '').trim();
  if (ex.isNotEmpty) return ex;

  final slug = _publicProfilePathSlug(handle: handle, userId: userId);
  if (slug.isEmpty) return '';

  final pubRaw = publicWebBaseFromDefine ?? RemoteBackendConfig.publicWebBaseUrl;
  final pub = pubRaw.trim().replaceAll(RegExp(r'/+$'), '');
  if (pub.isNotEmpty) return '$pub/u/$slug';

  final apiRaw = apiBaseFromDefine ?? RemoteBackendConfig.apiBaseUrl;
  final api = apiRaw.trim().replaceAll(RegExp(r'/+$'), '');
  if (_isNonLoopbackHttpOrigin(api)) return '$api/u/$slug';
  return '';
}

String _publicProfilePathSlug({
  required String? handle,
  required String? userId,
}) {
  var h = (handle ?? '').trim();
  if (h.startsWith('@')) h = h.substring(1).trim();
  if (h.isNotEmpty) return Uri.encodeComponent(h);
  final uid = (userId ?? '').trim();
  if (uid.isNotEmpty) return Uri.encodeComponent(uid);
  return '';
}

bool _isNonLoopbackHttpOrigin(String s) {
  final lower = s.toLowerCase();
  if (lower.contains('localhost')) return false;
  if (lower.contains('127.0.0.1')) return false;
  if (lower.contains('[::1]')) return false;
  if (lower.contains('::1')) return false;
  return s.startsWith('http://') || s.startsWith('https://');
}

/// Host + path for compact display (e.g. `nimon.app/u/alice`).
String shortPublicProfileLinkLabel(String fullUrl) {
  final t = fullUrl.trim();
  if (t.isEmpty) return '';
  try {
    final u = Uri.parse(t);
    if (u.hasScheme && u.host.isNotEmpty) {
      final path = u.path.isEmpty ? '' : u.path;
      return '${u.host}$path';
    }
  } catch (_) {
    // fall through
  }
  return t;
}
