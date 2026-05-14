import { containsHtmlOrScript, trimText } from './text-normalization';
import type { ValidationIssue } from './validation-issue';
import { ValidationSeverity } from './validation-severity';
import { resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';

const EMAIL_RE =
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const WEAK_PASSWORDS = new Set(
  [
    'password',
    'password123',
    '12345678',
    'qwerty123',
    'nimon123',
    'letmein',
    'welcome',
    '11111111',
  ].map((s) => s.toLowerCase()),
);

function blocking(
  field: string,
  code: string,
  messageKey: string,
  params?: Record<string, unknown>,
): ValidationIssue {
  return {
    field,
    code,
    messageKey,
    severity: ValidationSeverity.Blocking,
    source: 'auth-validation',
    params,
  };
}

export function normalizeEmailInput(raw: string | null | undefined): string {
  return trimText(raw ?? '').toLowerCase();
}

export function validateEmailFormat(raw: string | null | undefined): ValidationResult {
  const email = normalizeEmailInput(raw);
  if (!email) {
    return resultFromIssues([
      blocking('email', 'auth.email.required', 'auth.email.required'),
    ]);
  }

  const issues: ValidationIssue[] = [];
  const len = email.length;
  if (len < 5 || len > 254) {
    issues.push(
      blocking(
        'email',
        'auth.email.length',
        'auth.email.length',
        { min: 5, max: 254, actual: len },
      ),
    );
  }

  if (/\s/.test(email) || /[\r\n]/.test(email)) {
    issues.push(
      blocking('email', 'auth.email.invalid', 'auth.email.invalid'),
    );
  }

  if (/\p{Extended_Pictographic}/u.test(email)) {
    issues.push(
      blocking('email', 'auth.email.invalid', 'auth.email.invalid'),
    );
  }

  if (containsHtmlOrScript(email)) {
    issues.push(
      blocking('email', 'auth.email.unsafe', 'auth.email.unsafe'),
    );
  }

  if (!EMAIL_RE.test(email)) {
    issues.push(
      blocking('email', 'auth.email.invalid', 'auth.email.invalid'),
    );
  }

  return resultFromIssues(issues);
}

export function validatePasswordRegister(raw: string | null | undefined): ValidationResult {
  const pw = raw == null ? '' : String(raw);
  const issues: ValidationIssue[] = [];

  if (/[\r\n]/.test(pw)) {
    issues.push(
      blocking(
        'password',
        'password.lineBreak',
        'auth.password.lineBreak',
      ),
    );
  }

  const len = pw.length;
  if (len < 8 || len > 64) {
    issues.push(
      blocking(
        'password',
        'auth.password.length',
        'auth.password.length',
        { min: 8, max: 64, actual: len },
      ),
    );
  }

  if (WEAK_PASSWORDS.has(pw.toLowerCase())) {
    issues.push(
      blocking(
        'password',
        'auth.password.weak',
        'auth.password.weak',
      ),
    );
  }

  return resultFromIssues(issues);
}

export function validateLoginPayload(input: {
  email?: string | null;
  password?: string | null;
}): ValidationResult {
  const issues: ValidationIssue[] = [];
  const email = normalizeEmailInput(input.email);
  if (!email) {
    issues.push(
      blocking('email', 'auth.email.required', 'auth.email.required'),
    );
  } else {
    issues.push(...validateEmailFormat(email).issues);
  }

  const pw = input.password == null ? '' : String(input.password);
  if (!pw) {
    issues.push(
      blocking(
        'password',
        'auth.password.requiredLogin',
        'auth.password.requiredLogin',
      ),
    );
  } else if (pw.length > 64) {
    issues.push(
      blocking(
        'password',
        'auth.password.length',
        'auth.password.length',
        { min: 8, max: 64, actual: pw.length },
      ),
    );
  }

  return resultFromIssues(issues);
}

export function validateRegisterPayload(input: {
  email?: string | null;
  password?: string | null;
}): ValidationResult {
  const emailRes = validateEmailFormat(input.email);
  const passRes = validatePasswordRegister(input.password);
  const issues = [...emailRes.issues, ...passRes.issues];
  return resultFromIssues(issues);
}
