import 'package:flutter/material.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/l10n/app_localizations.dart';

/// Title + message + optional secondary for premium-adjacent copy (no navigation).
class QuotaExceededStrings {
  const QuotaExceededStrings({
    required this.title,
    required this.message,
    required this.showPremiumSecondary,
  });

  final String title;
  final String message;
  final bool showPremiumSecondary;
}

QuotaExceededStrings resolveQuotaExceededStrings(
  AppLocalizations l10n,
  AppQuotaExceededException q,
) {
  switch (q.key) {
    case 'published_mono_limit_reached':
      return QuotaExceededStrings(
        title: l10n.publishedMonoLimitReachedTitle,
        message: l10n.publishedMonoLimitReachedMessage(q.limit),
        showPremiumSecondary: true,
      );
    case 'saved_mono_limit_reached':
      return QuotaExceededStrings(
        title: l10n.savedMonoLimitReachedTitle,
        message: l10n.savedMonoLimitReachedMessage(q.limit),
        showPremiumSecondary: false,
      );
    case 'collection_limit_reached':
      return QuotaExceededStrings(
        title: l10n.collectionLimitReachedTitle,
        message: l10n.collectionLimitReachedMessage(q.limit),
        showPremiumSecondary: true,
      );
    case 'collection_item_limit_reached':
      return QuotaExceededStrings(
        title: l10n.collectionItemLimitReachedTitle,
        message: l10n.collectionItemLimitReachedMessage(q.limit),
        showPremiumSecondary: false,
      );
    case 'draft_story_limit_reached':
      return QuotaExceededStrings(
        title: l10n.draftStoryLimitReachedTitle,
        message: l10n.draftStoryLimitReachedMessage(q.limit),
        showPremiumSecondary: false,
      );
    default:
      return QuotaExceededStrings(
        title: l10n.quotaUnknownLimitTitle,
        message: l10n.quotaUnknownLimitMessage,
        showPremiumSecondary: false,
      );
  }
}

/// Localized quota dialog; safe when [context] is unmounted.
Future<void> showQuotaExceededDialog(
  BuildContext context,
  AppQuotaExceededException quota,
) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return;
  final copy = resolveQuotaExceededStrings(l10n, quota);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(copy.title),
      content: Text(copy.message),
      actions: [
        if (copy.showPremiumSecondary)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.quotaPremiumComingLaterCta),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.quotaDialogOk),
        ),
      ],
    ),
  );
}
