import 'package:flutter/widgets.dart';

import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/ui/blocking_loading_overlay.dart' as nimon_overlay;

/// Shows a blocking loading overlay while [discardStaging] runs.
///
/// M17E-7: the overlay is always dismissed in `finally` **before** this
/// function returns, so callers can show a quota dialog or snackbar without
/// stacking loaders on top of alerts.
typedef OpenBlockingLoadingOverlay = VoidCallback Function(
  BuildContext context,
  String message,
);

Future<({bool success, AppQuotaExceededException? quota})>
    discardPublishedEditStagingWithBlockingOverlay({
  required BuildContext context,
  required Future<bool> Function() discardStaging,
  OpenBlockingLoadingOverlay openBlockingLoading =
      nimon_overlay.showBlockingLoadingOverlay,
}) async {
  final closeLoading = openBlockingLoading(context, 'Cancelling edit…');
  AppQuotaExceededException? quota;
  var discarded = false;
  try {
    discarded = await discardStaging();
  } on AppQuotaExceededException catch (e) {
    quota = e;
  } finally {
    closeLoading();
  }
  if (quota != null) {
    return (success: false, quota: quota);
  }
  return (success: discarded, quota: null);
}
