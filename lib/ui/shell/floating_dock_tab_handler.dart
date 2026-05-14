import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';

/// Main shell + mono reader dock: Mono (0), Add (1), Profile (2).
///
/// M17K: guests cannot open Add or Profile without passing
/// [ensureProtectedActionAllowed] (same UX as other protected actions).
Future<void> handleFloatingDockTabSelection(
  BuildContext context, {
  required StatefulNavigationShell? navigationShell,
  required int index,
  required void Function(BuildContext context) openCreate,
}) async {
  final go = GoRouter.of(context);
  final path = go.state.uri.path;
  final onCreateStack = path.startsWith('/create');

  switch (index) {
    case 0:
      if (onCreateStack) {
        go.go('/mono');
      } else if (navigationShell != null) {
        navigationShell.goBranch(0);
      } else {
        go.go('/mono');
      }
      return;
    case 1:
      if (path == '/create' || path.startsWith('/create?')) {
        return;
      }
      if (!await ensureProtectedActionAllowed(
        context,
        action: ProtectedActionType.createStory,
      )) {
        return;
      }
      if (!context.mounted) return;
      openCreate(context);
      return;
    case 2:
      if (!await ensureProtectedActionAllowed(
        context,
        action: ProtectedActionType.editProfile,
      )) {
        return;
      }
      if (!context.mounted) return;
      if (onCreateStack) {
        go.go('/more');
      } else if (navigationShell != null) {
        navigationShell.goBranch(1);
      } else {
        go.go('/more');
      }
      return;
    default:
      return;
  }
}
