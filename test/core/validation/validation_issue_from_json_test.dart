import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/validation_issue_from_json.dart';
import 'package:nimon/core/validation/validation_severity.dart';

void main() {
  test('parses Nest-style validation_failed payload', () {
    final body = jsonEncode({
      'statusCode': 400,
      'message': 'validation_failed',
      'issues': [
        {
          'code': 'story.title.required',
          'field': 'story.title',
          'messageKey': 'story.title.required',
          'severity': 'blocking',
          'source': 'publish-validation',
        },
      ],
    });
    final issues = tryParseValidationIssuesFromHttpBody(body);
    expect(issues, isNotNull);
    expect(issues!.length, 1);
    expect(issues.first.messageKey, 'story.title.required');
    expect(issues.first.severity, ValidationSeverity.blocking);
  });

  test('non-validation 400 body yields null', () {
    final body = jsonEncode({'statusCode': 400, 'message': 'other'});
    expect(tryParseValidationIssuesFromHttpBody(body), isNull);
  });

  test('parses top-level issues when message is object with nested issues', () {
    final body = jsonEncode({
      'message': {
        'message': 'validation_failed',
        'issues': [
          {
            'code': 'x',
            'field': 'custom.field',
            'messageKey': 'x',
            'severity': 'blocking',
          },
        ],
      },
    });
    final issues = tryParseValidationIssuesFromHttpBody(body);
    expect(issues, isNotNull);
    expect(issues!.single.field, 'custom.field');
  });

  test('parses issues array when message string is validation_failed', () {
    final body = jsonEncode({
      'message': 'validation_failed',
      'issues': [
        {
          'code': 'y',
          'field': 'unknown',
          'messageKey': 'y',
          'severity': 'warning',
        },
      ],
    });
    final issues = tryParseValidationIssuesFromHttpBody(body);
    expect(issues, isNotNull);
    expect(issues!.single.severity, ValidationSeverity.warning);
  });
}
