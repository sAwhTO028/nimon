import 'package:flutter/material.dart';
import 'package:nimon/features/create/widgets/creator_fit_info_bottom_sheet.dart';

/// Long plain-text help (quiz / listening): same fit-to-content sheet as other creator
/// info surfaces, with scroll only when copy exceeds the max height.
void showNimonScrollableHelpBottomSheet({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = 'Got it',
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  showCreatorFitInfoBottomSheet(
    context: context,
    title: title,
    children: [
      Text(
        body,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    ],
    actionLabel: confirmLabel,
  );
}
