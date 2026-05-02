import 'package:flutter/foundation.dart';

/// Set to `true` locally to print `[creator_nav|...]` lines from [creatorNavDebug] (kDebugMode only).
const bool kCreatorNavigationDebugVerbose = false;

void creatorNavDebug(String tag, String message) {
  if (!kDebugMode || !kCreatorNavigationDebugVerbose) return;
  debugPrint('[creator_nav|$tag] $message');
}
