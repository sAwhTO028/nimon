import 'validation_fallback_messages.dart';
import 'validation_issue.dart';
import 'validation_result.dart';
import 'validation_severity.dart';

/// First blocking [ValidationIssue] for [field], or `null`.
ValidationIssue? firstBlockingIssueForField(
    ValidationResult result, String field) {
  for (final i in result.issues) {
    if (i.field != field) continue;
    if (i.severity != ValidationSeverity.blocking) continue;
    return i;
  }
  return null;
}

/// First blocking issue message for [field], or `null`.
String? firstBlockingMessageForField(ValidationResult result, String field) {
  final issue = firstBlockingIssueForField(result, field);
  return issue == null ? null : validationIssueDisplayMessage(issue);
}

/// Runs [validator] on [value] and returns the first blocking message for [field].
String? validateFieldForTextForm(
  ValidationResult Function(String value) validator,
  String value,
  String field,
) {
  return firstBlockingMessageForField(validator(value), field);
}

/// Maps blocking issues by field id (last blocking issue wins per field).
Map<String, ValidationIssue> blockingIssuesByField(
    List<ValidationIssue> issues) {
  final out = <String, ValidationIssue>{};
  for (final i in issues) {
    if (i.severity != ValidationSeverity.blocking) continue;
    out[i.field] = i;
  }
  return out;
}

/// Maps blocking issues by field id (last blocking issue wins per field).
Map<String, String> fieldErrorsFromIssues(List<ValidationIssue> issues) {
  final out = <String, String>{};
  for (final i in issues) {
    if (i.severity != ValidationSeverity.blocking) continue;
    out[i.field] = validationIssueDisplayMessage(i);
  }
  return out;
}

/// First blocking issue not covered by [mappedFields], if any.
ValidationIssue? firstUnhandledBlockingIssue(
  List<ValidationIssue> issues,
  Set<String> mappedFields,
) {
  for (final i in issues) {
    if (i.severity != ValidationSeverity.blocking) continue;
    if (mappedFields.contains(i.field)) continue;
    return i;
  }
  return null;
}

/// Human-readable fallback when [issues] cannot be tied to a specific field.
String? firstUnhandledBlockingMessage(
  List<ValidationIssue> issues,
  Set<String> mappedFields,
) {
  final issue = firstUnhandledBlockingIssue(issues, mappedFields);
  return issue == null ? null : validationIssueDisplayMessage(issue);
}
