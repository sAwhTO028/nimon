import 'package:flutter/material.dart';

/// Lightweight modal barrier + spinner for long mutations.
///
/// Call the returned closure to dismiss. Safe to call multiple times or after
/// the route is gone (no-op).
VoidCallback showBlockingLoadingOverlay(
  BuildContext context,
  String message,
) {
  if (!context.mounted) {
    return () {};
  }
  final nav = Navigator.of(context, rootNavigator: true);
  var closed = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black45,
    useRootNavigator: true,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return () {
    if (closed) return;
    closed = true;
    if (nav.mounted && nav.canPop()) {
      nav.pop();
    }
  };
}
