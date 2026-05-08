import 'package:flutter/foundation.dart' show kDebugMode;

/// Debug-only: whether `?creator=` without `userId` may show the legacy mock profile UI.
///
/// Release/profile builds must not treat handle-only routes as a real creator profile.
bool legacyDemoCreatorProfileActive({
  required String? userId,
  required String? creatorHandle,
  bool isDebugMode = kDebugMode,
}) {
  final uid = (userId ?? '').trim();
  final ch = (creatorHandle ?? '').trim();
  return uid.isEmpty && ch.isNotEmpty && isDebugMode;
}

/// Non-debug builds: opening `/profile/public?creator=` without `userId` must not load mock data.
bool creatorHandleOnlyRouteRejectedOutsideDebug({
  required String? userId,
  required String? creatorHandle,
  bool isDebugMode = kDebugMode,
}) {
  final uid = (userId ?? '').trim();
  final ch = (creatorHandle ?? '').trim();
  return uid.isEmpty && ch.isNotEmpty && !isDebugMode;
}
