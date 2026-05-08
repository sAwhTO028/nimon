/// Canonical public creator profile route builder.
///
/// Policy (M8a):
/// - Prefer **`userId`** → `/profile/public?userId=` (production).
/// - Legacy **`?creator=`** only when [allowLegacyHandle] is true (mock/demo/debug).
///   Release builds must not present mock profiles for handle-only routes — see
/// [legacyDemoCreatorProfileActive] in `public_profile_routing_policy.dart`.
String? creatorProfileLocation({
  required String? userId,
  required String? handle,
  required bool allowLegacyHandle,
}) {
  final uid = (userId ?? '').trim();
  if (uid.isNotEmpty) {
    return '/profile/public?userId=${Uri.encodeComponent(uid)}';
  }
  final h = (handle ?? '').trim();
  if (!allowLegacyHandle) {
    return null;
  }
  if (h.isEmpty) {
    return null;
  }
  return '/profile/public?creator=${Uri.encodeComponent(h)}';
}
