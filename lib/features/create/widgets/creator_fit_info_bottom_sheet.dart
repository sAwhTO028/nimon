import 'package:flutter/material.dart';

/// Keys for widget tests (M14E fit-to-content info sheets).
const ValueKey<String> creatorFitInfoBottomSheetKey =
    ValueKey('creatorFitInfoBottomSheet');
const ValueKey<String> creatorFitInfoTitleKey = ValueKey('creatorFitInfoTitle');
const ValueKey<String> creatorFitInfoGotItButtonKey =
    ValueKey('creatorFitInfoGotItButton');

/// Custom drag pill inside the sheet (M14F: avoid modal [showDragHandle] drawing above the card).
const ValueKey<String> creatorFitInfoBottomSheetHandleKey =
    ValueKey('creatorFitInfoBottomSheetHandle');

/// Creator module info / "how it works" bottom sheet sized to content (Story Basics
/// progress sheet pattern: [ConstrainedBox] max height only, [Column] [mainAxisSize.min],
/// scroll only when content exceeds max height).
///
/// Do **not** use fixed [FractionallySizedBox] height factors for short static copy.
/// The drag handle is **inside** the rounded [Material] so it does not float at the
/// top of the screen (see M14F).
Future<void> showCreatorFitInfoBottomSheet({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  String actionLabel = 'Got it',
  bool showActionButton = true,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final maxH = mq.size.height * 0.80;

      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mq.size.width,
                maxHeight: maxH,
              ),
              child: Material(
                key: creatorFitInfoBottomSheetKey,
                color: cs.surface,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    10,
                    28,
                    20 + mq.viewPadding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          key: creatorFitInfoBottomSheetHandleKey,
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        key: creatorFitInfoTitleKey,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...children,
                      if (showActionButton) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            key: creatorFitInfoGotItButtonKey,
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(actionLabel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
