import type { ValidationIssue } from './validation-issue';
import { ValidationSeverity } from './validation-severity';

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
    source: 'media-validation',
    params,
  };
}

/** Missing multipart `file` field entirely. */
export function issueMediaFileRequired(): ValidationIssue {
  return blocking(
    'media.file',
    'media.file.required',
    'media.file.required',
  );
}

/** Present field but zero-length buffer. */
export function issueMediaFileEmpty(): ValidationIssue {
  return blocking('media.file', 'media.file.empty', 'media.file.empty');
}

/** Generic client-side / unknown upload slot size exceeded (e.g. Multer limit). */
export function issueMediaFileTooLarge(maxBytes: number): ValidationIssue {
  return blocking(
    'media.file',
    'media.file.tooLarge',
    'media.file.tooLarge',
    { maxBytes },
  );
}

export function issueMediaImageTooLarge(maxBytes: number): ValidationIssue {
  return blocking(
    'coverImage',
    'media.image.tooLarge',
    'media.image.tooLarge',
    { maxBytes },
  );
}

export function issueMediaAudioTooLarge(maxBytes: number): ValidationIssue {
  return blocking(
    'audioFile',
    'media.audio.tooLarge',
    'media.audio.tooLarge',
    { maxBytes },
  );
}
