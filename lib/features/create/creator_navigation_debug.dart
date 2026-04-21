import 'package:flutter/foundation.dart';

/// TEMPORARY: flip to `false` to silence all creator navigation / embed diagnostics.
/// Remove this file's usages when verification is complete.
const bool kCreatorNavigationDebugVerbose = true;

void creatorNavDebug(String tag, String message) {
  if (!kDebugMode || !kCreatorNavigationDebugVerbose) return;
  debugPrint('[creator_nav|$tag] $message');
}
