import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/form_validation_adapter.dart';
import 'package:nimon/core/validation/profile_validators.dart';
import 'package:nimon/core/validation/story_validators.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

ValidationIssue _issue({
  required String field,
  required String messageKey,
  required ValidationSeverity severity,
}) {
  return ValidationIssue(
    code: 't',
    field: field,
    messageKey: messageKey,
    severity: severity,
    source: 'test',
  );
}

void main() {
  group('firstBlockingIssueForField', () {
    test('returns issue for matching blocking field', () {
      final r = ValidationResult(
        ok: false,
        issues: [
          _issue(
            field: 'handle',
            messageKey: 'profile.handle.reserved',
            severity: ValidationSeverity.blocking,
          ),
        ],
      );
      final issue = firstBlockingIssueForField(r, 'handle');
      expect(issue?.messageKey, 'profile.handle.reserved');
    });
  });

  group('firstBlockingMessageForField', () {
    test('returns message for matching blocking field', () {
      final r = ValidationResult(
        ok: false,
        issues: [
          _issue(
            field: 'handle',
            messageKey: 'profile.handle.reserved',
            severity: ValidationSeverity.blocking,
          ),
        ],
      );
      expect(
        firstBlockingMessageForField(r, 'handle'),
        isNotNull,
      );
    });

    test('ignores warnings for blocking helper', () {
      final r = ValidationResult(
        ok: true,
        issues: [
          _issue(
            field: 'story.title',
            messageKey: 'story.title.recommended',
            severity: ValidationSeverity.warning,
          ),
        ],
      );
      expect(firstBlockingMessageForField(r, 'story.title'), isNull);
    });
  });

  group('fieldErrorsFromIssues', () {
    test('blocking issues become map entries', () {
      final m = fieldErrorsFromIssues([
        _issue(
          field: 'email',
          messageKey: 'auth.email.invalid',
          severity: ValidationSeverity.blocking,
        ),
      ]);
      expect(m.containsKey('email'), true);
      expect(m['email']!.isNotEmpty, true);
    });

    test('warnings omitted from map', () {
      final m = fieldErrorsFromIssues([
        _issue(
          field: 'x',
          messageKey: 'story.title.recommended',
          severity: ValidationSeverity.warning,
        ),
      ]);
      expect(m.isEmpty, true);
    });
  });

  group('validateFieldForTextForm', () {
    test('maps validator output to field', () {
      final msg = validateFieldForTextForm(
        (v) => validateHandle(v),
        '!!!',
        'handle',
      );
      expect(msg, isNotNull);
    });
  });

  group('story draft validators', () {
    test('empty title in draft yields warning not blocking error text', () {
      final r = validateStoryTitle('', ValidationMode.draft);
      expect(firstBlockingMessageForField(r, 'story.title'), isNull);
    });

    test('script in title is blocking in draft', () {
      final r = validateStoryTitle('<script>', ValidationMode.draft);
      expect(firstBlockingMessageForField(r, 'story.title'), isNotNull);
    });
  });
}
