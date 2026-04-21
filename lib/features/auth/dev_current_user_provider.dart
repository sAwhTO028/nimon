import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fixed development identity until real auth replaces [devCurrentUserProvider].
class DevCurrentUser {
  const DevCurrentUser({
    required this.userId,
    this.displayName,
  });

  /// Stable string id (future: maps to auth subject / account id).
  final String userId;

  /// Optional label for debug UI; not used in persistence.
  final String? displayName;
}

/// Single source of truth for “current user” in development builds.
///
/// Swap this provider’s implementation for a real session when backend auth lands.
final devCurrentUserProvider = Provider<DevCurrentUser>((ref) {
  return const DevCurrentUser(
    userId: 'dev_user_1',
    displayName: 'Dev User',
  );
});
