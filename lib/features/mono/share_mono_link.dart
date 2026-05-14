import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/l10n/nimon_app_strings.dart';

/// Resolves the link to copy: backend [MonoFeedItem.shareUrl] wins; then
/// [RemoteBackendConfig.publicWebBaseUrl]; then non-loopback [RemoteBackendConfig.apiBaseUrl].
/// Never uses `localhost` / `127.0.0.1` / `::1` from fallbacks (shows unavailable instead).
@visibleForTesting
String resolveMonoShareUrlForItem(
  MonoFeedItem item, {
  String publicWebBaseFromDefine = RemoteBackendConfig.publicWebBaseUrl,
  String apiBaseFromDefine = RemoteBackendConfig.apiBaseUrl,
}) {
  final u = item.shareUrl?.trim() ?? '';
  if (u.isNotEmpty) return u;
  final pub = publicWebBaseFromDefine.trim().replaceAll(RegExp(r'/+$'), '');
  if (pub.isNotEmpty) {
    return '$pub/mono/${item.monoIdForLearnRoutes}';
  }
  final api = apiBaseFromDefine.trim().replaceAll(RegExp(r'/+$'), '');
  if (_isNonLoopbackHttpOrigin(api)) {
    return '$api/mono/${item.monoIdForLearnRoutes}';
  }
  return '';
}

/// Production-safe accessor for a share link (may be empty).
///
/// This is intentionally **not** `@visibleForTesting` so other libraries (e.g. reader
/// menus) can check whether sharing is available without duplicating URL rules.
String monoShareUrlOrEmpty(MonoFeedItem item) =>
    resolveMonoShareUrlForItem(item);

bool _isNonLoopbackHttpOrigin(String s) {
  final lower = s.toLowerCase();
  if (lower.contains('localhost')) return false;
  if (lower.contains('127.0.0.1')) return false;
  if (lower.contains('[::1]')) return false;
  if (lower.contains('::1')) return false;
  return s.startsWith('http://') || s.startsWith('https://');
}

/// Copies the canonical mono share link to the clipboard and shows a snackbar.
///
/// - Prefer backend [MonoFeedItem.shareUrl]; else [resolveMonoShareUrlForItem].
/// - If still empty: shows [NimonAppStrings.shareLinkUnavailable] and does not copy body text.
///
/// System share sheet (`share_plus`) is intentionally **not** wired here pending product
/// approval to add the dependency; see `docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md`.
Future<void> shareMonoLink(BuildContext context, MonoFeedItem item) async {
  final link = resolveMonoShareUrlForItem(item);
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
