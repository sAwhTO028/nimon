import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';

import 'nimon_network_online_provider.dart';
import 'protected_action.dart';
import 'localized_validation_messages.dart';

/// Runs [checkProtectedAction] with auth + network from Riverpod and handles UX:
/// - **allowed** → `true`
/// - **networkRequired** → snackbar with `network.offline`, `false`
/// - **loginRequired** / **forbidden** / **disabledByPolicy** → [showProtectedActionPrompt], `false`
///
/// Uses [ProviderScope.containerOf] so it works from any [BuildContext] under the app scope.
Future<bool> ensureProtectedActionAllowed(
  BuildContext context, {
  required ProtectedActionType action,
}) async {
  final container = ProviderScope.containerOf(context);
  final session = container.read(authSessionProvider);
  final isAuthed = session is AuthSessionAuthenticated;
  final online = container.read(nimonNetworkOnlineProvider);

  final decision = checkProtectedAction(
    action,
    authState: AuthStateSummary(isAuthenticated: isAuthed),
    networkState: NetworkStateSummary(isOnline: online),
  );

  switch (decision) {
    case ProtectedActionDecision.allowed:
      return true;
    case ProtectedActionDecision.networkRequired:
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validationMessageKeyLocalized(context, 'network.offline'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    case ProtectedActionDecision.loginRequired:
    case ProtectedActionDecision.forbidden:
    case ProtectedActionDecision.disabledByPolicy:
      if (!context.mounted) return false;
      await showProtectedActionPrompt(context, decision, action);
      return false;
  }
}
