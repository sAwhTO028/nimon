import { BadRequestException } from '@nestjs/common';
import { ValidationSeverity } from './validation-severity';
import {
  assertNoBlockingValidationIssues,
  throwValidationFailed,
  validationFailedException,
} from './validation-exception';
import { ok, resultFromIssues } from './validation-result';
import type { ValidationIssue } from './validation-issue';

const blockingIssue: ValidationIssue = {
  field: 'email',
  code: 'email.invalid',
  messageKey: 'email.invalid',
  severity: ValidationSeverity.Blocking,
  source: 'test',
};

describe('validation-exception', () => {
  it('validationFailedException builds Nest 400 with validation_failed shape', () => {
    const ex = validationFailedException([blockingIssue]);
    expect(ex).toBeInstanceOf(BadRequestException);
    expect(ex.getStatus()).toBe(400);
    const body = ex.getResponse() as Record<string, unknown>;
    expect(body['message']).toBe('validation_failed');
    expect(Array.isArray(body['issues'])).toBe(true);
    expect((body['issues'] as ValidationIssue[])[0].field).toBe('email');
  });

  it('throwValidationFailed never returns', () => {
    expect(() => throwValidationFailed([blockingIssue])).toThrow(
      BadRequestException,
    );
  });

  it('assertNoBlockingValidationIssues passes when no blocking issues', () => {
    expect(() => assertNoBlockingValidationIssues(ok())).not.toThrow();
    expect(() =>
      assertNoBlockingValidationIssues(
        resultFromIssues([
          {
            field: 'x',
            code: 'x',
            messageKey: 'x',
            severity: ValidationSeverity.Warning,
            source: 'test',
          },
        ]),
      ),
    ).not.toThrow();
  });

  it('assertNoBlockingValidationIssues throws validation_failed', () => {
    expect(() =>
      assertNoBlockingValidationIssues(resultFromIssues([blockingIssue])),
    ).toThrow(BadRequestException);
    try {
      assertNoBlockingValidationIssues(resultFromIssues([blockingIssue]));
    } catch (e) {
      const body = (e as BadRequestException).getResponse() as Record<
        string,
        unknown
      >;
      expect(body['message']).toBe('validation_failed');
    }
  });
});
