// Auth domain models aligned with nimon-backend `/v1/auth` and `/v1/me`.

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'tokenType': tokenType,
      };
}

class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.handle,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? handle;
}

/// Persisted token pair (secure storage only — never in SharedPreferences).
class StoredAuthTokens {
  const StoredAuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}
