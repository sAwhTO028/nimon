import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  PayloadTooLargeException,
} from '@nestjs/common';

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
      const res = ctx.getResponse<{
        status: (c: number) => { json: (b: unknown) => void };
      }>();
      const ex = new PayloadTooLargeException(
        'File exceeds maximum allowed size for this upload.',
      );
      res.status(ex.getStatus()).json(ex.getResponse());
      return;
    }
    throw exception;
  }
}
