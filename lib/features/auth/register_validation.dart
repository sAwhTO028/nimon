/// Client-side register form validation (mirrors backend `MinLength(8)` on password).
const int kRegisterMinPasswordLength = 8;

const String kRegisterEmailEmpty = 'Enter your email.';
const String kRegisterPasswordMinLength =
    'Password must be at least 8 characters.';
const String kRegisterPasswordMismatch = 'Passwords do not match.';

/// Returns a single user-facing error for the first invalid field, or `null` if valid.
String? validateRegisterForm({
  required String email,
  required String password,
  required String confirmPassword,
  int minPasswordLength = kRegisterMinPasswordLength,
}) {
  if (email.trim().isEmpty) {
    return kRegisterEmailEmpty;
  }
  if (password.length < minPasswordLength) {
    return kRegisterPasswordMinLength;
  }
  if (password != confirmPassword) {
    return kRegisterPasswordMismatch;
  }
  return null;
}
