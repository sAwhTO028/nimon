import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_token_store.dart';

class _FakeAuthTokenStoreForTest implements AuthTokenStore {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<StoredAuthTokens?> readTokens() async => null;

  @override
  Future<void> writeTokens(StoredAuthTokens tokens) async {}
}

class TestAuthSessionNotifierForTest extends AuthSessionNotifier {
  TestAuthSessionNotifierForTest(AuthSessionState initial)
      : super(
          AuthRepository(apiBaseUrl: 'http://127.0.0.1:9'),
          _FakeAuthTokenStoreForTest(),
        ) {
    state = initial;
  }
}

/// Use in [ProviderScope.overrides] so `ensureProtectedActionAllowed` and
/// edit profile / collection flows see a signed-in user.
Override authenticatedAuthSessionOverride = authSessionProvider.overrideWith(
  (_) => TestAuthSessionNotifierForTest(
    AuthSessionAuthenticated(
      AuthUser(id: 'u1', email: 'a@b.com'),
    ),
  ),
);
