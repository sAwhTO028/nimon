import 'package:flutter/widgets.dart';
import 'package:nimon/core/media/media_upload_error_mapper.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';

/// Result of attempting to upload a gallery pick to the M5c media API.
class StoryBasicsCoverUploadOutcome {
  const StoryBasicsCoverUploadOutcome._({
    this.response,
    this.inlineHint,
  });

  final MediaUploadResponse? response;

  /// Short line under the thumbnail when upload did not persist remotely.
  /// **null** means rely on snackbars only (e.g. sign-in prompt already shown).
  final String? inlineHint;

  bool get isSuccess => response != null;

  factory StoryBasicsCoverUploadOutcome.ok(MediaUploadResponse r) =>
      StoryBasicsCoverUploadOutcome._(response: r);

  /// Gallery pick can still show local preview; [inlineHint] optional.
  factory StoryBasicsCoverUploadOutcome.pendingLocal({String? inlineHint}) =>
      StoryBasicsCoverUploadOutcome._(inlineHint: inlineHint);
}

/// Maps upload failures to an optional inline hint (never duplicates “sign in” for network).
String? coverUploadFailureInlineHint(Object error) {
  final msg = mediaUploadUserMessage(
    error,
    surface: MediaUploadSurface.storyCover,
  ).toLowerCase();
  if (msg.contains('sign in') || msg.contains('session expired')) {
    return null;
  }
  if (msg.contains('could not reach') ||
      msg.contains('connection') ||
      msg.contains('network') ||
      msg.contains('internet')) {
    return 'Upload failed. Try again.';
  }
  return msg.length > 80 ? '${msg.substring(0, 77)}…' : msg;
}

/// Same as [coverUploadFailureInlineHint] but uses localized validation/media copy.
String? coverUploadFailureInlineHintLocalized(
  BuildContext context,
  Object error,
) {
  final msg = mediaUploadUserMessageLocalized(
    context,
    error,
    surface: MediaUploadSurface.storyCover,
  ).toLowerCase();
  if (msg.contains('sign in') || msg.contains('session expired')) {
    return null;
  }
  if (msg.contains('could not reach') ||
      msg.contains('connection') ||
      msg.contains('network') ||
      msg.contains('internet')) {
    return 'Upload failed. Try again.';
  }
  return msg.length > 80 ? '${msg.substring(0, 77)}…' : msg;
}
