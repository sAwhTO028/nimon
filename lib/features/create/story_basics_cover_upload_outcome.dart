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

/// Maps [MediaUploadException] to an optional inline hint (never duplicates “sign in” for network).
String? coverUploadFailureInlineHint(MediaUploadException e) {
  final sc = e.statusCode;
  final msg = e.userMessage.toLowerCase();
  if (msg.contains('sign in') || msg.contains('session expired')) {
    return null;
  }
  if (msg.contains('could not reach') ||
      msg.contains('connection') ||
      msg.contains('network')) {
    return 'Upload failed. Try again.';
  }
  if (sc == 413) {
    return 'Image is too large.';
  }
  if (sc == 415) {
    return 'This format is not supported.';
  }
  if (sc == 400) {
    return 'Upload failed. Try again.';
  }
  return 'Upload failed. Try again.';
}
