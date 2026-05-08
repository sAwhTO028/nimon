import type { Readable } from 'node:stream';

/**
 * Multer memory-upload file shape (aligned with multer + `@nestjs/platform-express`),
 * declared locally so builds stay stable across `@types/express` major versions.
 */
export type MulterMemoryUploadedFile = {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
  destination: string;
  filename: string;
  path: string;
  stream?: Readable;
};
