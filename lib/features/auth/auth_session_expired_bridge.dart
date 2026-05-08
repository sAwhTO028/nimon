import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

/// [MaterialApp.router] / [GoRouter] navigator — assigned in [main.dart].
final nimonAppNavigatorKey = GlobalKey<NavigatorState>();

/// Registers strict-remote **401** handling (clear session, snackbar, `/login`).
///
/// Avoids passing [BuildContext] into repositories.
class AuthSessionExpiredBridge {
  AuthSessionExpiredBridge._();

  /// Singleton used by guarded HTTP helpers when [notifyExpired] runs.
  static final AuthSessionExpiredBridge instance = AuthSessionExpiredBridge._();

  Future<void> Function()? _handler;

  /// Called from [NimonApp] with session clear + navigation.
  void register(Future<void> Function()? handler) {
    _handler = handler;
  }

  /// Invoked when `RemoteBackendConfig.strictRemoteDrafts` and HTTP **401**.
  void notifyExpired() {
    final h = _handler;
    if (h == null) return;
    unawaited(h());
  }
}
