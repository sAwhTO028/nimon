import 'package:nimon/core/validation/reserved_words.dart';
import 'package:nimon/core/validation/text_normalization.dart'
    show
        charLength,
        containsHtmlOrScript,
        countEmojis,
        countLines,
        normalizeSingleLineText,
        trimText;
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

ValidationIssue _block(
  String field,
  String code,
  String messageKey, [
  Map<String, Object?>? params,
]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'profile_validators',
      params: params,
    );

ValidationResult validateDisplayName(String? raw) {
  if (raw == null) return okResult();
  final normalized = normalizeSingleLineText(raw);
  if (normalized.isEmpty) {
    return resultFromIssues([
      _block(
        'displayName',
        'profile.displayName.required',
        'profile.displayName.required',
      ),
    ]);
  }
  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len < 1 || len > 30) {
    issues.add(
      _block(
        'displayName',
        'profile.displayName.length',
        'profile.displayName.length',
        {'min': 1, 'max': 30, 'actual': len},
      ),
    );
  }
  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'displayName',
        'profile.displayName.unsafe',
        'profile.displayName.unsafe',
      ),
    );
  }
  return resultFromIssues(issues);
}

ValidationResult validateHandle(String? raw) {
  if (raw == null) return okResult();
  var h = trimText(raw);
  if (h.startsWith('@')) h = h.substring(1);
  final lower = h.toLowerCase();
  if (lower.isEmpty) return okResult();

  final issues = <ValidationIssue>[];

  if (countEmojis(lower) > 0) {
    issues.add(
        _block('handle', 'profile.handle.noEmoji', 'profile.handle.noEmoji'));
  }

  if (lower.length < 3 || lower.length > 24) {
    issues.add(
      _block(
        'handle',
        'profile.handle.length',
        'profile.handle.length',
        {'min': 3, 'max': 24, 'actual': lower.length},
      ),
    );
  }

  if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(lower)) {
    issues.add(
      _block(
        'handle',
        'profile.handle.invalidChars',
        'profile.handle.invalidChars',
      ),
    );
  }

  if (lower.startsWith('.') || lower.endsWith('.')) {
    issues.add(
      _block(
        'handle',
        'profile.handle.periodEdge',
        'profile.handle.periodEdge',
      ),
    );
  }

  if (lower.contains('..')) {
    issues.add(
      _block(
        'handle',
        'profile.handle.periodRepeat',
        'profile.handle.periodRepeat',
      ),
    );
  }

  if (isReservedHandle(lower)) {
    issues.add(
      _block('handle', 'profile.handle.reserved', 'profile.handle.reserved'),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateBio(String? raw) {
  if (raw == null) return okResult();
  final t = trimText(raw);
  if (t.isEmpty) return okResult();

  final issues = <ValidationIssue>[];
  final len = charLength(t);
  if (len > 150) {
    issues.add(
      _block(
        'bio',
        'profile.bio.tooLong',
        'profile.bio.tooLong',
        {'max': 150, 'actual': len},
      ),
    );
  }
  if (containsHtmlOrScript(t)) {
    issues.add(_block('bio', 'profile.bio.unsafe', 'profile.bio.unsafe'));
  }
  if (countLines(t) > 3) {
    issues.add(
      _block(
        'bio',
        'profile.bio.tooManyLines',
        'profile.bio.tooManyLines',
        {'max': 3},
      ),
    );
  }
  return resultFromIssues(issues);
}
