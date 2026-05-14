import 'package:nimon/core/validation/text_normalization.dart'
    show containsHtmlOrScript, trimText;
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const _weakPasswords = <String>{
  'password',
  'password123',
  '12345678',
  'qwerty123',
  'nimon123',
  'letmein',
  'welcome',
  '11111111',
};

ValidationIssue _block(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'auth_validators',
      params: params,
    );

String normalizeEmailInput(String? raw) => trimText(raw).toLowerCase();

ValidationResult validateEmailFormat(String? raw) {
  final email = normalizeEmailInput(raw);
  if (email.isEmpty) {
    return resultFromIssues([
      _block('email', 'auth.email.required', 'auth.email.required'),
    ]);
  }

  final issues = <ValidationIssue>[];
  final len = email.length;
  if (len < 5 || len > 254) {
    issues.add(
      _block(
        'email',
        'auth.email.length',
        'auth.email.length',
        {'min': 5, 'max': 254, 'actual': len},
      ),
    );
  }

  if (RegExp(r'\s').hasMatch(email) || RegExp(r'[\r\n]').hasMatch(email)) {
    issues.add(_block('email', 'auth.email.invalid', 'auth.email.invalid'));
  }

  if (RegExp(r'\p{Extended_Pictographic}', unicode: true).hasMatch(email)) {
    issues.add(_block('email', 'auth.email.invalid', 'auth.email.invalid'));
  }

  if (containsHtmlOrScript(email)) {
    issues.add(_block('email', 'auth.email.unsafe', 'auth.email.unsafe'));
  }

  if (!_emailRe.hasMatch(email)) {
    issues.add(_block('email', 'auth.email.invalid', 'auth.email.invalid'));
  }

  return resultFromIssues(issues);
}

ValidationResult validatePassword(String? raw) {
  final pw = raw ?? '';
  final issues = <ValidationIssue>[];

  if (RegExp(r'[\r\n]').hasMatch(pw)) {
    issues.add(
      _block('password', 'password.lineBreak', 'auth.password.lineBreak'),
    );
  }

  final len = pw.length;
  if (len < 8 || len > 64) {
    issues.add(
      _block(
        'password',
        'auth.password.length',
        'auth.password.length',
        {'min': 8, 'max': 64, 'actual': len},
      ),
    );
  }

  if (_weakPasswords.contains(pw.toLowerCase())) {
    issues.add(
      _block('password', 'auth.password.weak', 'auth.password.weak'),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateLoginFields({
  required String? email,
  required String? password,
}) {
  final issues = <ValidationIssue>[];
  final em = normalizeEmailInput(email);
  if (em.isEmpty) {
    issues.add(_block('email', 'auth.email.required', 'auth.email.required'));
  } else {
    issues.addAll(validateEmailFormat(em).issues);
  }

  final pw = password ?? '';
  if (pw.isEmpty) {
    issues.add(
      _block(
        'password',
        'auth.password.requiredLogin',
        'auth.password.requiredLogin',
      ),
    );
  } else if (pw.length > 64) {
    issues.add(
      _block(
        'password',
        'auth.password.length',
        'auth.password.length',
        {'min': 8, 'max': 64, 'actual': pw.length},
      ),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateRegisterFields({
  required String? email,
  required String? password,
}) {
  final emailRes = validateEmailFormat(email);
  final passRes = validatePassword(password);
  return resultFromIssues([...emailRes.issues, ...passRes.issues]);
}

ValidationResult validateConfirmPasswordMatch(
  String? password,
  String? confirm,
) {
  if ((password ?? '') != (confirm ?? '')) {
    return resultFromIssues([
      _block(
        'confirmPassword',
        'auth.confirmPassword.mismatch',
        'auth.confirmPassword.mismatch',
      ),
    ]);
  }
  return okResult();
}

/// Register: email, password, and confirm match (confirm is not sent to API).
ValidationResult validateRegisterFormFields({
  required String? email,
  required String? password,
  required String? confirmPassword,
}) {
  return combineResults([
    validateEmailFormat(email),
    validatePassword(password),
    validateConfirmPasswordMatch(password, confirmPassword),
  ]);
}
