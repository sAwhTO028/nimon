import {
  charLength,
  containsHtmlOrScript,
  countEmojis,
  containsUrl,
  hasExcessiveRepeatedCharacters,
  isOnlyNumbers,
  isOnlySymbols,
  normalizeSingleLineText,
  trimText,
} from './text-normalization';
import type { ValidationIssue } from './validation-issue';
import { ValidationSeverity } from './validation-severity';
import { resultFromIssues } from './validation-result';
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
    source: 'collection-validation',
    params,
  };
}

export function validateCollectionName(raw: string | null | undefined): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  const issues: ValidationIssue[] = [];

  if (!normalized) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.required',
        'collection.title.required',
      ),
    );
    return resultFromIssues(issues);
  }

  const len = charLength(normalized);
  if (len < 1 || len > 40) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.length',
        'collection.title.length',
        { min: 1, max: 40, actual: len },
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.unsafe',
        'collection.title.unsafe',
      ),
    );
  }

  if (/[\r\n]/.test(trimText(raw ?? ''))) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.lineBreak',
        'collection.title.lineBreak',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.noUrl',
        'collection.title.noUrl',
      ),
    );
  }

  if (countEmojis(normalized) > 1) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.tooManyEmoji',
        'collection.title.tooManyEmoji',
      ),
    );
  }

  if (isOnlyNumbers(normalized)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.onlyNumbers',
        'collection.title.onlyNumbers',
      ),
    );
  }

  if (isOnlySymbols(normalized)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.onlySymbols',
        'collection.title.onlySymbols',
      ),
    );
  }

  if (!/\p{L}|\p{N}/u.test(normalized)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.onlySpaces',
        'collection.title.onlySpaces',
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.push(
      blocking(
        'collection.title',
        'collection.title.excessiveRepeat',
        'collection.title.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues);
}
