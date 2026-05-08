import 'package:nimon/features/auth/auth_models.dart';

/// Riverpod session state for `/v1/me`-identified users.
sealed class AuthSessionState {
  const AuthSessionState();
}

/// Before [restoreSession] runs (e.g. first frame).
class AuthSessionUnknown extends AuthSessionState {
  const AuthSessionUnknown();
}

/// Loading tokens / calling `/v1/me`.
class AuthSessionLoading extends AuthSessionState {
  const AuthSessionLoading();
}

/// No valid session (guest / signed out).
class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();
}

/// Valid access + user from `/v1/me`.
class AuthSessionAuthenticated extends AuthSessionState {
  const AuthSessionAuthenticated(this.user);

  final AuthUser user;
}
