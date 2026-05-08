import 'package:nimon/features/auth/register_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validateRegisterForm: email empty', () {
    expect(
      validateRegisterForm(
        email: '',
        password: '12345678',
        confirmPassword: '12345678',
      ),
      kRegisterEmailEmpty,
    );
  });

  test('validateRegisterForm: password too short', () {
    expect(
      validateRegisterForm(
        email: 'a@b.com',
        password: 'short',
        confirmPassword: 'short',
      ),
      kRegisterPasswordMinLength,
    );
  });

  test('validateRegisterForm: mismatch', () {
    expect(
      validateRegisterForm(
        email: 'a@b.com',
        password: '12345678',
        confirmPassword: '87654321',
      ),
      kRegisterPasswordMismatch,
    );
  });

  test('validateRegisterForm: valid', () {
    expect(
      validateRegisterForm(
        email: 'a@b.com',
        password: '12345678',
        confirmPassword: '12345678',
      ),
      isNull,
    );
  });
}
