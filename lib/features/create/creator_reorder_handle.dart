import 'package:flutter/material.dart';

/// Drag handle used with [ReorderableDragStartListener] on creator cards.
///
/// Matches Story Sentences cards: no [Tooltip] (it competes with reorder drag).
class CreatorReorderHandle extends StatelessWidget {
  const CreatorReorderHandle({
    super.key,
    required this.theme,
    this.semanticsLabel = 'Drag to reorder',
  });

  final ThemeData theme;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Semantics(
      label: semanticsLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.drag_handle_rounded,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}
