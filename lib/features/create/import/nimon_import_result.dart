import 'package:nimon/features/create/import/nimon_import_enums.dart';

// -----------------------------------------------------------------------------
// Import validation outcome (validator + UI will consume this later).
//
// [canImport] and [canPublishImmediately] are intentionally separate:
// e.g. Full Learn with null/missing audio → canImport true, canPublishImmediately
// false, with audio called out in [missingPublishRequirements].
// -----------------------------------------------------------------------------

/// Single issue from import validation (structure, context, or publish readiness).
class NimonImportIssue {
  const NimonImportIssue({
    required this.code,
    required this.message,
    this.path,
    this.severity = NimonImportIssueSeverity.blocking,
  });

  final String code;
  final String message;

  /// JSON pointer–style path when useful (e.g. `nimonImportMeta.createdForEmail`).
  final String? path;
  final NimonImportIssueSeverity severity;

  @override
  String toString() {
    final p = path == null || path!.isEmpty ? '' : ' @$path';
    return 'NimonImportIssue($code$p: $message)';
  }
}

/// Result of import validation before mapping to [CreatorStoryV1].
class NimonImportValidationResult {
  const NimonImportValidationResult({
    required this.canImport,
    required this.canPublishImmediately,
    this.blockingErrors = const [],
    this.missingPublishRequirements = const [],
    this.warnings = const [],
  });

  /// When false, do not create a local draft (blocking structural/context errors).
  final bool canImport;

  /// When false, user may still open preview; publish drawer should stay blocked
  /// until requirements (e.g. audio upload) are satisfied.
  final bool canPublishImmediately;

  final List<NimonImportIssue> blockingErrors;
  final List<NimonImportIssue> missingPublishRequirements;
  final List<NimonImportIssue> warnings;

  bool get hasBlockingErrors => blockingErrors.isNotEmpty;

  bool get hasMissingPublishRequirements => missingPublishRequirements.isNotEmpty;

  /// Import allowed but not publish-ready (preview-only success path).
  bool get readyToPreviewOnly => canImport && !canPublishImmediately;

  /// Convenience: hard block with one or more errors.
  factory NimonImportValidationResult.blocked(
    List<NimonImportIssue> errors, {
    List<NimonImportIssue> warnings = const [],
  }) {
    return NimonImportValidationResult(
      canImport: false,
      canPublishImmediately: false,
      blockingErrors: errors,
      warnings: warnings,
    );
  }

  /// Import OK and publish preflight can pass immediately (validator sets this later).
  factory NimonImportValidationResult.importAndPublishReady({
    List<NimonImportIssue> warnings = const [],
  }) {
    return NimonImportValidationResult(
      canImport: true,
      canPublishImmediately: true,
      warnings: warnings,
    );
  }

  /// Import OK; user must complete steps (e.g. audio) before publish.
  factory NimonImportValidationResult.importPreviewOnly({
    required List<NimonImportIssue> missingPublishRequirements,
    List<NimonImportIssue> warnings = const [],
  }) {
    return NimonImportValidationResult(
      canImport: true,
      canPublishImmediately: false,
      missingPublishRequirements: missingPublishRequirements,
      warnings: warnings,
    );
  }

  @override
  String toString() =>
      'NimonImportValidationResult(canImport=$canImport, '
      'canPublishImmediately=$canPublishImmediately, '
      'blocking=${blockingErrors.length}, '
      'missingPublish=${missingPublishRequirements.length}, '
      'warnings=${warnings.length})';
}
