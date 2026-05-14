import { BadRequestException } from '@nestjs/common';
import {
  issueMediaAudioTooLarge,
  issueMediaFileRequired,
  issueMediaImageTooLarge,
} from './media-validation';
import { validationFailedException } from './validation-exception';

describe('media-validation issues', () => {
  it('validationFailedException wraps media.file.required', () => {
    const ex = validationFailedException([issueMediaFileRequired()]);
    expect(ex).toBeInstanceOf(BadRequestException);
    expect(ex.getStatus()).toBe(400);
    const body = ex.getResponse() as Record<string, unknown>;
    expect(body['message']).toBe('validation_failed');
    const issues = body['issues'] as Array<{ field?: string; messageKey?: string }>;
    expect(issues[0].field).toBe('media.file');
    expect(issues[0].messageKey).toBe('media.file.required');
  });

  it('image too large targets coverImage field', () => {
    const ex = validationFailedException([issueMediaImageTooLarge(10 * 1024 * 1024)]);
    const body = ex.getResponse() as Record<string, unknown>;
    const issues = body['issues'] as Array<{ field?: string }>;
    expect(issues[0].field).toBe('coverImage');
  });

  it('audio too large targets audioFile field', () => {
    const ex = validationFailedException([issueMediaAudioTooLarge(50 * 1024 * 1024)]);
    const body = ex.getResponse() as Record<string, unknown>;
    const issues = body['issues'] as Array<{ field?: string }>;
    expect(issues[0].field).toBe('audioFile');
  });
});
