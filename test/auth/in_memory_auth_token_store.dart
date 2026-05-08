import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_token_store.dart';

/// Test double for [SecureAuthTokenStore] (no platform plugin).
class InMemoryAuthTokenStore implements AuthTokenStore {
  StoredAuthTokens? _tokens;

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}
