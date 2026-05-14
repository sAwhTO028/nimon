import type { ValidationIssue } from './validation-issue';
import { ValidationSeverity } from './validation-severity';

export type ValidationResult = {
  ok: boolean;
  issues: ValidationIssue[];
};

export function ok(): ValidationResult {
  return { ok: true, issues: [] };
}

export function fail(issue: ValidationIssue): ValidationResult {
  return {
    ok: issue.severity !== ValidationSeverity.Blocking,
    issues: [issue],
  };
}

/** Merges multiple results; ok is true only when no blocking issues in any part. */
export function combine(...results: ValidationResult[]): ValidationResult {
  const issues = results.flatMap((r) => r.issues);
  const blocking = issues.some((i) => i.severity === ValidationSeverity.Blocking);
  return { ok: !blocking, issues };
}

export function hasBlockingIssues(result: ValidationResult): boolean {
  return result.issues.some((i) => i.severity === ValidationSeverity.Blocking);
}

export function resultFromIssues(issues: ValidationIssue[]): ValidationResult {
  const blocking = issues.some((i) => i.severity === ValidationSeverity.Blocking);
  return { ok: !blocking, issues };
}
