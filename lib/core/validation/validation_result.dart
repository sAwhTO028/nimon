import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';

class ValidationResult {
  const ValidationResult({required this.ok, required this.issues});

  final bool ok;
  final List<ValidationIssue> issues;
}

ValidationResult okResult() => const ValidationResult(ok: true, issues: []);

ValidationResult failResult(ValidationIssue issue) => ValidationResult(
      ok: issue.severity != ValidationSeverity.blocking,
      issues: [issue],
    );

ValidationResult combineResults(Iterable<ValidationResult> results) {
  final issues = results.expand((r) => r.issues).toList();
  final blocking = issues.any((i) => i.severity == ValidationSeverity.blocking);
  return ValidationResult(ok: !blocking, issues: issues);
}

ValidationResult resultFromIssues(List<ValidationIssue> issues) {
  final blocking = issues.any((i) => i.severity == ValidationSeverity.blocking);
  return ValidationResult(ok: !blocking, issues: issues);
}

bool hasBlockingIssues(ValidationResult r) =>
    r.issues.any((i) => i.severity == ValidationSeverity.blocking);
