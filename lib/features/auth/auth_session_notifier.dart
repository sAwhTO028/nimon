import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_token_store.dart';

class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  AuthSessionNotifier(this._repo, this._store)
      : super(const AuthSessionUnknown());

  final AuthRepository _repo;
  final AuthTokenStore _store;

  /// Bootstrap: secure tokens → `/v1/me`, refresh on failure, else clear.
  Future<void> restoreSession() async {
    state = const AuthSessionLoading();
    try {
      final stored = await _store.readTokens();
      if (stored == null ||
          stored.accessToken.isEmpty && stored.refreshToken.isEmpty) {
        state = const AuthSessionUnauthenticated();
        return;
      }

      var access = stored.accessToken;
      var refresh = stored.refreshToken;

      Future<AuthUser?> loadUser(String token) async {
        if (token.isEmpty) return null;
        try {
          return await _repo.getMe(accessToken: token);
        } on AuthRepositoryException {
          return null;
        }
      }

      var user = await loadUser(access);
      if (user == null && refresh.isNotEmpty) {
        try {
          final t = await _repo.refresh(refreshToken: refresh);
          await _store.writeTokens(
            StoredAuthTokens(
              accessToken: t.accessToken,
              refreshToken: t.refreshToken,
            ),
          );
          access = t.accessToken;
          refresh = t.refreshToken;
          user = await loadUser(access);
        } on AuthRepositoryException {
          user = null;
        }
      }

      if (user == null) {
        await _store.clearTokens();
        state = const AuthSessionUnauthenticated();
        return;
      }

      state = AuthSessionAuthenticated(user);
    } catch (_) {
      await _store.clearTokens();
      state = const AuthSessionUnauthenticated();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthSessionLoading();
    try {
      final tokens = await _repo.login(email: email, password: password);
      await _store.writeTokens(
        StoredAuthTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ),
      );
      final user = await _repo.getMe(accessToken: tokens.accessToken);
      state = AuthSessionAuthenticated(user);
    } on AuthRepositoryException {
      state = const AuthSessionUnauthenticated();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AuthSessionLoading();
    try {
      final tokens = await _repo.register(email: email, password: password);
      await _store.writeTokens(
        StoredAuthTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ),
      );
      final user = await _repo.getMe(accessToken: tokens.accessToken);
      state = AuthSessionAuthenticated(user);
    } on AuthRepositoryException {
      state = const AuthSessionUnauthenticated();
      rethrow;
    }
  }

  Future<void> logout() async {
    final stored = await _store.readTokens();
    final rt = stored?.refreshToken ?? '';
    if (rt.isNotEmpty) {
      try {
        await _repo.logout(refreshToken: rt);
      } catch (_) {
        // Best-effort revoke; always clear local session.
      }
    }
    await _store.clearTokens();
    state = const AuthSessionUnauthenticated();
  }

  /// Clears secure tokens without calling `/v1/auth/logout` (e.g. strict 401 from API).
  Future<void> forceSessionExpired() async {
    await _store.clearTokens();
    state = const AuthSessionUnauthenticated();
  }

  /// Updates in-memory session after [AuthRefresh401Coordinator] persists rotated tokens.
  void applyAuthenticatedUser(AuthUser user) {
    state = AuthSessionAuthenticated(user);
  }
}
