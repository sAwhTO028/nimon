import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

/// True when remote draft sync is on but there is no JWT-backed session.
final guestRemoteDraftWarningVisibleProvider = Provider<bool>((ref) {
  return computeGuestRemoteDraftWarning(
    useRemoteDrafts: RemoteBackendConfig.useRemoteDrafts,
    session: ref.watch(authSessionProvider),
  );
});

bool computeGuestRemoteDraftWarning({
  required bool useRemoteDrafts,
  required AuthSessionState session,
}) {
  if (!useRemoteDrafts) return false;
  return session is! AuthSessionAuthenticated;
}
