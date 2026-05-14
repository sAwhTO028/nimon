import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';

/// Routes that must not paint until session hydration finishes (no login flash).
/// `/create/**`, `/learn/**`, `/settings`, etc. may load while tokens are still resolving.
bool routeRequiresSessionBootstrap(String location) {
  if (location == '/login' || location == '/register') return true;
  if (location == '/mono' ||
      location.startsWith('/mono/') ||
      location == '/mono-reader') {
    return true;
  }
  if (location == '/more' || location.startsWith('/more?')) return true;
  return false;
}

/// M17L: Shown while [AuthSessionUnknown] / [AuthSessionLoading] — not the login page.
class AuthStartupSplashScreen extends StatelessWidget {
  const AuthStartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Icon(
          Icons.hourglass_empty_rounded,
          size: 48,
          color: scheme.primary,
        ),
      ),
    );
  }
}

String authSessionStateLabel(AuthSessionState auth) {
  return switch (auth) {
    AuthSessionUnknown _ => 'unknown',
    AuthSessionLoading _ => 'loading',
    AuthSessionUnauthenticated _ => 'unauthenticated',
    AuthSessionAuthenticated _ => 'authenticated',
  };
}

/// Pure routing rules for startup / login vs shell (unit-tested).
///
/// [location] must be [GoRouterState.uri.path] (no query).
String? resolveNimonAuthStartupRedirect({
  required AuthSessionState auth,
  required String location,
}) {
  final checking = auth is AuthSessionUnknown || auth is AuthSessionLoading;
  if (checking) {
    if (routeRequiresSessionBootstrap(location) && location != '/startup') {
      return '/startup';
    }
    return null;
  }

  if (auth is AuthSessionAuthenticated) {
    if (location == '/login' ||
        location == '/register' ||
        location == '/startup') {
      return '/mono';
    }
    return null;
  }

  if (location == '/startup') {
    return '/login';
  }
  return null;
}

String? nimonAuthRedirect(BuildContext context, GoRouterState state) {
  final auth = ProviderScope.containerOf(context, listen: false)
      .read(authSessionProvider);
  final location = state.uri.path;
  final target =
      resolveNimonAuthStartupRedirect(auth: auth, location: location);
  debugPrint(
    '[AuthRouter] location=$location authState=${authSessionStateLabel(auth)} redirect=${target ?? 'none'}',
  );
  return target;
}
