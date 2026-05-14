import 'package:nimon/core/validation/text_normalization.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

ValidationIssue _block(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'collection_validators',
      params: params,
    );

ValidationResult validateCollectionName(String? raw) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  final issues = <ValidationIssue>[];

  if (normalized.isEmpty) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.required',
        'collection.title.required',
      ),
    );
    return resultFromIssues(issues);
  }

  final len = charLength(normalized);
  if (len < 1 || len > 40) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.length',
        'collection.title.length',
        {'min': 1, 'max': 40, 'actual': len},
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.unsafe',
        'collection.title.unsafe',
      ),
    );
  }

  if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.lineBreak',
        'collection.title.lineBreak',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.noUrl',
        'collection.title.noUrl',
      ),
    );
  }

  if (countEmojis(normalized) > 1) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.tooManyEmoji',
        'collection.title.tooManyEmoji',
      ),
    );
  }

  if (isOnlyNumbers(normalized)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.onlyNumbers',
        'collection.title.onlyNumbers',
      ),
    );
  }

  if (isOnlySymbols(normalized)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.onlySymbols',
        'collection.title.onlySymbols',
      ),
    );
  }

  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(normalized)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.onlySpaces',
        'collection.title.onlySpaces',
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.add(
      _block(
        'collection.title',
        'collection.title.excessiveRepeat',
        'collection.title.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues);
}
