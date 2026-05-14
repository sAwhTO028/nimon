import {
  charLength,
  containsHtmlOrScript,
  countLines,
  normalizeSingleLineText,
  trimText,
} from './text-normalization';
import { isReservedHandle } from './reserved-words';
import type { ValidationIssue } from './validation-issue';
import { ValidationSeverity } from './validation-severity';
import { ok, resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';

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
    source: 'profile-validation',
    params,
  };
}

export function validateProfileDisplayName(
  raw: string | null | undefined,
): ValidationResult {
  if (raw == null || raw === undefined) return ok();
  const normalized = normalizeSingleLineText(trimText(raw));
  if (!normalized) {
    return resultFromIssues([
      blocking(
        'displayName',
        'profile.displayName.required',
        'profile.displayName.required',
      ),
    ]);
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len < 1 || len > 30) {
    issues.push(
      blocking(
        'displayName',
        'profile.displayName.length',
        'profile.displayName.length',
        { min: 1, max: 30, actual: len },
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'displayName',
        'profile.displayName.unsafe',
        'profile.displayName.unsafe',
      ),
    );
  }

  return resultFromIssues(issues);
}

export function validateProfileHandle(raw: string | null | undefined): ValidationResult {
  if (raw == null || raw === undefined) return ok();
  let h = trimText(raw);
  if (h.startsWith('@')) h = h.slice(1);
  const lower = h.toLowerCase();
  if (!lower) return ok();

  const issues: ValidationIssue[] = [];

  if (/\p{Extended_Pictographic}/u.test(lower)) {
    issues.push(
      blocking('handle', 'profile.handle.noEmoji', 'profile.handle.noEmoji'),
    );
  }

  if (lower.length < 3 || lower.length > 24) {
    issues.push(
      blocking(
        'handle',
        'profile.handle.length',
        'profile.handle.length',
        { min: 3, max: 24, actual: lower.length },
      ),
    );
  }

  if (!/^[a-z0-9_.]+$/.test(lower)) {
    issues.push(
      blocking(
        'handle',
        'profile.handle.invalidChars',
        'profile.handle.invalidChars',
      ),
    );
  }

  if (lower.startsWith('.') || lower.endsWith('.')) {
    issues.push(
      blocking(
        'handle',
        'profile.handle.periodEdge',
        'profile.handle.periodEdge',
      ),
    );
  }

  if (lower.includes('..')) {
    issues.push(
      blocking(
        'handle',
        'profile.handle.periodRepeat',
        'profile.handle.periodRepeat',
      ),
    );
  }

  if (isReservedHandle(lower)) {
    issues.push(
      blocking(
        'handle',
        'profile.handle.reserved',
        'profile.handle.reserved',
      ),
    );
  }

  return resultFromIssues(issues);
}

export function validateProfileBio(raw: string | null | undefined): ValidationResult {
  if (raw == null || raw === undefined) return ok();
  const t = trimText(raw);
  if (!t) return ok();

  const issues: ValidationIssue[] = [];
  const len = charLength(t);
  if (len > 150) {
    issues.push(
      blocking(
        'bio',
        'profile.bio.tooLong',
        'profile.bio.tooLong',
        { max: 150, actual: len },
      ),
    );
  }

  if (containsHtmlOrScript(t)) {
    issues.push(
      blocking('bio', 'profile.bio.unsafe', 'profile.bio.unsafe'),
    );
  }

  if (countLines(t) > 3) {
    issues.push(
      blocking(
        'bio',
        'profile.bio.tooManyLines',
        'profile.bio.tooManyLines',
        { max: 3 },
      ),
    );
  }

  return resultFromIssues(issues);
}
