import { BadRequestException } from '@nestjs/common';
import type { ValidationIssue } from './validation-issue';
import {
  hasBlockingIssues,
  type ValidationResult,
} from './validation-result';

export function validationFailedException(
  issues: ValidationIssue[],
): BadRequestException {
  return new BadRequestException({
    message: 'validation_failed',
    issues,
  });
}

export function throwValidationFailed(issues: ValidationIssue[]): never {
  throw validationFailedException(issues);
}

/** Throws [BadRequestException] with `validation_failed` when the result has blocking issues. */
export function assertNoBlockingValidationIssues(result: ValidationResult): void {
  if (hasBlockingIssues(result)) {
    throwValidationFailed(result.issues);
  }
}
