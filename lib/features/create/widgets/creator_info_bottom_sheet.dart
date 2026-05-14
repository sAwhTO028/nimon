import 'package:flutter/material.dart';

import 'package:nimon/features/create/widgets/creator_fit_info_bottom_sheet.dart';

/// Bullet row for creator "how it works" / help sheets (matches Vocabulary/Grammar bullets).
class CreatorInfoBullet extends StatelessWidget {
  const CreatorInfoBullet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 8, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical list of [CreatorInfoBullet] rows.
class CreatorInfoBulletColumn extends StatelessWidget {
  const CreatorInfoBulletColumn({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final line in lines) CreatorInfoBullet(text: line)],
    );
  }
}

/// Single-body variant of [showCreatorFitInfoBottomSheet] (Story Basics–style fit height).
///
/// For long plain-text bodies, prefer [showNimonScrollableHelpBottomSheet], which also
/// uses the fit sheet with scroll capped by max height.
void showCreatorInfoBottomSheet({
  required BuildContext context,
  required String title,
  required Widget body,
  String confirmLabel = 'Got it',
  bool showConfirmButton = true,
}) {
  showCreatorFitInfoBottomSheet(
    context: context,
    title: title,
    children: [body],
    actionLabel: confirmLabel,
    showActionButton: showConfirmButton,
  );
}
