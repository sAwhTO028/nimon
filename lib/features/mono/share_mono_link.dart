import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/l10n/nimon_app_strings.dart';

/// Copies the canonical mono share link to the clipboard and shows a snackbar.
///
/// - If [MonoFeedItem.shareUrl] is present: copies it and shows [NimonAppStrings.shareLinkCopied].
/// - Otherwise: shows [NimonAppStrings.shareLinkUnavailable] and does not copy body text.
///
/// System share sheet (`share_plus`) is intentionally **not** wired here pending product
/// approval to add the dependency; see `docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md`.
Future<void> shareMonoLink(BuildContext context, MonoFeedItem item) async {
  final link = item.shareUrl?.trim() ?? '';
  if (link.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(NimonAppStrings.shareLinkUnavailable),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(NimonAppStrings.shareLinkCopied),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 2),
    ),
  );
}
