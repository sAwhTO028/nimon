import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';

final remotePublicCreatorProfileRepositoryProvider =
    Provider<RemotePublicCreatorProfileRepository>((ref) {
  return RemotePublicCreatorProfileRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
  );
});

/// Signed-in user’s public profile (`GET /v1/users/:userId/public-profile`) for
/// owner header metrics (followers / following). Guests yield `null` data.
final currentUserPublicProfileProvider =
    FutureProvider.autoDispose<PublicCreatorProfile?>((ref) async {
  if (!RemoteBackendConfig.useRemoteDrafts) {
    return null;
  }
  final session = ref.watch(authSessionProvider);
  if (session is! AuthSessionAuthenticated) {
    return null;
  }
  final uid = session.user.id.trim();
  if (uid.isEmpty) {
    return null;
  }
  final repo = ref.watch(remotePublicCreatorProfileRepositoryProvider);
  try {
    return await repo.fetchPublicCreatorProfile(uid);
  } catch (_) {
    return null;
  }
});
