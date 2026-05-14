import 'package:flutter/widgets.dart';
import 'package:nimon/core/networking/network_error_mapping.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/validation_fallback_messages.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/l10n/app_localizations.dart';

/// Upload contexts for tailored generic fallback copy when no structured issue exists.
enum MediaUploadSurface {
  storyCover,
  listeningAudio,
  profileAvatar,
  profileCover,
}

bool isMediaValidationError(Object error) =>
    error is HttpValidationFailedException;

String _genericUploadMessage(MediaUploadSurface surface) {
  switch (surface) {
    case MediaUploadSurface.listeningAudio:
      return 'Could not upload audio. Please try again.';
    case MediaUploadSurface.storyCover:
    case MediaUploadSurface.profileAvatar:
    case MediaUploadSurface.profileCover:
      return 'Could not upload image. Please try again.';
  }
}

/// Maps upload failures to safe, user-facing copy (no raw backend strings).
String mediaUploadUserMessage(
  Object error, {
  required MediaUploadSurface surface,
}) {
  if (error is HttpValidationFailedException) {
    for (final issue in error.issues) {
      if (issue.severity == ValidationSeverity.blocking) {
        return validationIssueDisplayMessage(issue);
      }
    }
    if (error.issues.isNotEmpty) {
      return validationIssueDisplayMessage(error.issues.first);
    }
    return _genericUploadMessage(surface);
  }
  if (error is MediaUploadException) {
    return error.userMessage;
  }
  final offline = offlineUserMessageIfRecognized(error);
  if (offline != null) return offline;
  return _genericUploadMessage(surface);
}

/// Localized user-facing message for media upload failures (UI layers).
String mediaUploadUserMessageLocalized(
  BuildContext context,
  Object error, {
  required MediaUploadSurface surface,
}) {
  if (error is HttpValidationFailedException) {
    for (final issue in error.issues) {
      if (issue.severity == ValidationSeverity.blocking) {
        return validationIssueDisplayMessageLocalized(context, issue);
      }
    }
    if (error.issues.isNotEmpty) {
      return validationIssueDisplayMessageLocalized(
        context,
        error.issues.first,
      );
    }
    return _genericUploadMessageLocalized(context, surface);
  }
  if (error is MediaUploadException) {
    return error.userMessage;
  }
  final offline = offlineUserMessageIfRecognized(error);
  if (offline != null) {
    return validationMessageKeyLocalized(context, 'network.offline');
  }
  return _genericUploadMessageLocalized(context, surface);
}

String _genericUploadMessageLocalized(
  BuildContext context,
  MediaUploadSurface surface,
) {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) {
    return _genericUploadMessage(surface);
  }
  return switch (surface) {
    MediaUploadSurface.listeningAudio => l10n.validationMediaUploadGenericAudio,
    _ => l10n.validationMediaUploadGenericImage,
  };
}
