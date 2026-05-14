import type { ValidationSeverity } from './validation-severity';

export type ValidationIssue = {
  code: string;
  field: string;
  messageKey: string;
  severity: ValidationSeverity;
  params?: Record<string, unknown>;
  source?: string;
};
