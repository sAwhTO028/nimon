import 'package:nimon/core/validation/validation_severity.dart';

class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.field,
    required this.messageKey,
    required this.severity,
    this.params,
    this.source,
  });

  final String code;
  final String field;
  final String messageKey;
  final ValidationSeverity severity;
  final Map<String, Object?>? params;
  final String? source;
}
