import 'package:flutter/material.dart';
import 'package:nimon/models/episode_meta.dart';
import 'package:nimon/ui/bottom_sheets/episode_bottom_sheet.dart';

/// Backwards-compatible helper used by tests and older call sites.
///
/// V1: this delegates to the global episode bottom sheet.
Future<void> showEpisodeModalFromMeta(
  BuildContext context,
  EpisodeMeta meta, {
  VoidCallback? onSave,
  VoidCallback? onStartReading,
}) async {
  await showEpisodeBottomSheetFromMeta(context, meta);

  // Callback hooks are accepted for compatibility; the current bottom sheet
  // implementation owns navigation actions internally (V1).
  //
  // When the sheet is refactored to be fully callback-driven, wire these in.
  onSave?.call();
  onStartReading?.call();
}

