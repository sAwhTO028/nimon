import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nimon/features/auth/auth_models.dart';

/// Persists access + refresh tokens using platform secure storage.
abstract class AuthTokenStore {
  Future<StoredAuthTokens?> readTokens();

  Future<void> writeTokens(StoredAuthTokens tokens);

  Future<void> clearTokens();
}

/// Keys are namespaced to avoid collisions with other app data.
class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kAccess = 'nimon_auth_access_token_v1';
  static const _kRefresh = 'nimon_auth_refresh_token_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthTokens?> readTokens() async {
    final access = (await _storage.read(key: _kAccess))?.trim() ?? '';
    final refresh = (await _storage.read(key: _kRefresh))?.trim() ?? '';
    if (access.isEmpty && refresh.isEmpty) return null;
    return StoredAuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> writeTokens(StoredAuthTokens tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
