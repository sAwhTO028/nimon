import 'package:flutter/material.dart';

/// App-level (root) messenger for route-safe snackbars.
///
/// Use this instead of `ScaffoldMessenger.of(context)` for async flows where the
/// originating page can be popped/deactivated before the feedback is shown.
final GlobalKey<ScaffoldMessengerState> nimonRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'nimon_root_scaffold_messenger');

void nimonShowRootSnackBar(SnackBar snackBar) {
  final state = nimonRootScaffoldMessengerKey.currentState;
  if (state == null) return;
  state.showSnackBar(snackBar);
}

/// Shows a snackbar only after navigation has had a chance to settle.
///
/// Rationale: during fast publish→back overlaps, the scaffold tree can be
/// transitioning and `showSnackBar` can crash in `_updateScaffolds`. We prefer
/// dropping the message over crashing.
void nimonShowRootSnackBarAfterRouteSettles(
  SnackBar snackBar, {
  int maxFrames = 6,
}) {
  var remaining = maxFrames;

  void attempt() {
    if (remaining-- <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = nimonRootScaffoldMessengerKey.currentState;
      if (state == null) {
        attempt();
        return;
      }
      try {
        state.showSnackBar(snackBar);
      } catch (_) {
        // Scaffold tree still unstable; retry next frame.
        attempt();
      }
    });
  }

  attempt();
}

