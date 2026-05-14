import { type ArgumentsHost, Catch, type ExceptionFilter } from '@nestjs/common';
import { validationFailedException } from '../../common/validation/validation-exception';
import {
  issueMediaAudioTooLarge,
  issueMediaImageTooLarge,
} from '../../common/validation/media-validation';
import {
  readAudioMaxBytesFromEnv,
  readCoverMaxBytesFromEnv,
} from './media-file-limits';

function getMulterCode(exception: unknown): string | undefined {
  if (typeof exception !== 'object' || exception === null) {
    return undefined;
  }
  const code = (exception as { code?: unknown }).code;
  return typeof code === 'string' ? code : undefined;
}

/**
 * Maps multer errors to Nest HTTP exceptions (e.g. LIMIT_FILE_SIZE → 413).
 */
@Catch()
export class MulterExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const code = getMulterCode(exception);
    if (code === 'LIMIT_FILE_SIZE') {
      const ctx = host.switchToHttp();
      const req = ctx.getRequest<{ originalUrl?: string; url?: string }>();
      const path = `${req.originalUrl ?? ''}${req.url ?? ''}`;
      const isAudio = path.includes('/upload/audio');
      const maxBytes = isAudio
        ? readAudioMaxBytesFromEnv()
        : readCoverMaxBytesFromEnv();
      const issues = isAudio
        ? [issueMediaAudioTooLarge(maxBytes)]
        : [issueMediaImageTooLarge(maxBytes)];
      const ex = validationFailedException(issues);
      const res = ctx.getResponse<{
        status: (c: number) => { json: (b: unknown) => void };
      }>();
      res.status(ex.getStatus()).json(ex.getResponse());
      return;
    }
    throw exception;
  }
}
