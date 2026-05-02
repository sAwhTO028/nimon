import { HttpException, HttpStatus } from '@nestjs/common';

type ApiErrorBody = {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
};

export function apiError(
  status: HttpStatus,
  code: string,
  message: string,
  details?: Record<string, unknown>,
): HttpException {
  const body: ApiErrorBody = {
    error: {
      code,
      message,
      ...(details ? { details } : {}),
    },
  };
  return new HttpException(body, status);
}

