import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_token_store.dart';

/// Single-flight refresh used when a protected HTTP call gets **401** with a
/// Bearer token (see [AuthenticatedHttp]).
class AuthRefresh401Coordinator {
  AuthRefresh401Coordinator({
    required AuthRepository authRepository,
    required AuthTokenStore tokenStore,
    required AuthSessionNotifier sessionNotifier,
  })  : _authRepository = authRepository,
        _tokenStore = tokenStore,
        _sessionNotifier = sessionNotifier;

  final AuthRepository _authRepository;
  final AuthTokenStore _tokenStore;
  final AuthSessionNotifier _sessionNotifier;

  Future<bool>? _inFlight;

  /// Returns `true` when new tokens were persisted and session user refreshed.
  ///
  /// On failure (no refresh token, refresh rejected, or `/v1/me` after refresh
  /// fails): clears tokens and session via [AuthSessionNotifier.forceSessionExpired].
  Future<bool> tryRecoverAfterUnauthorized401() async {
    final existing = _inFlight;
    if (existing != null) return await existing;

    final run = _recover();
    _inFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    }
  }

  Future<bool> _recover() async {
    final tokens = await _tokenStore.readTokens();
    final rt = tokens?.refreshToken.trim() ?? '';
    if (rt.isEmpty) {
      await _sessionNotifier.forceSessionExpired();
      return false;
    }
    try {
      final t = await _authRepository.refresh(refreshToken: rt);
      await _tokenStore.writeTokens(
        StoredAuthTokens(
          accessToken: t.accessToken,
          refreshToken: t.refreshToken,
        ),
      );
      final user = await _authRepository.getMe(accessToken: t.accessToken);
      _sessionNotifier.applyAuthenticatedUser(user);
      return true;
    } on AuthRepositoryException {
      await _sessionNotifier.forceSessionExpired();
      return false;
    }
  }
}
