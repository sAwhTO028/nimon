import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_refresh_401_coordinator.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_token_store.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

/// Platform secure storage for JWT pair.
final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return SecureAuthTokenStore();
});

/// [AuthRepository] uses [RemoteBackendConfig.apiBaseUrl] (single compile-time API origin).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiBaseUrl: RemoteBackendConfig.apiBaseUrl);
});

/// Shared `/v1/story-drafts` + `/v1/published-monos` Authorization header builder.
final authHeaderBuilderProvider =
    Provider<Future<Map<String, String>> Function()>((ref) {
  final store = ref.watch(authTokenStoreProvider);
  return () async {
    final t = await store.readTokens();
    if (t == null) return <String, String>{};
    final a = t.accessToken.trim();
    if (a.isEmpty) return <String, String>{};
    return <String, String>{'Authorization': 'Bearer $a'};
  };
});

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>((ref) {
  return AuthSessionNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(authTokenStoreProvider),
  );
});

final authRefresh401CoordinatorProvider =
    Provider<AuthRefresh401Coordinator>((ref) {
  return AuthRefresh401Coordinator(
    authRepository: ref.watch(authRepositoryProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
    sessionNotifier: ref.read(authSessionProvider.notifier),
  );
});

final nimonSendWithAuth401RecoveryProvider =
    Provider<NimonSendWithAuth401Recovery>((ref) {
  final coordinator = ref.watch(authRefresh401CoordinatorProvider);
  return nimonSendWithAuth401RecoveryFromCoordinator(coordinator);
});
