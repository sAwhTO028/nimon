import 'validation_issue.dart';

/// Backend responded with `{ message: 'validation_failed', issues: [...] }`.
class HttpValidationFailedException implements Exception {
  HttpValidationFailedException(this.issues);

  final List<ValidationIssue> issues;

  @override
  String toString() =>
      'HttpValidationFailedException(${issues.length} issue(s))';
}
