import { HttpException, HttpStatus } from '@nestjs/common';

export type QuotaExceededBody = {
  code: 'quota_exceeded';
  key: string;
  limit: number;
  current: number;
};

/**
 * Free-tier quota block (M17E). HTTP 403 — authenticated user may not perform the mutation.
 * Response body is the contract surface for Flutter (M17F); no internal-only message field.
 */
export class QuotaExceededException extends HttpException {
  constructor(key: string, limit: number, current: number) {
    const body: QuotaExceededBody = {
      code: 'quota_exceeded',
      key,
      limit,
      current,
    };
    super(body, HttpStatus.FORBIDDEN);
  }
}
