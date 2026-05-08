import type { Readable } from 'node:stream';
import type { MulterMemoryUploadedFile } from './media-upload.types';

/** Matches multer `StorageEngine` shape without importing the `multer` package. */
export type MulterLikeStorageEngine = {
  _handleFile(
    req: unknown,
    file: MulterMemoryUploadedFile,
    cb: (
      error?: Error | null,
      info?: Partial<MulterMemoryUploadedFile>,
    ) => void,
  ): void;
  _removeFile(
    req: unknown,
    file: MulterMemoryUploadedFile,
    cb: (error: Error | null) => void,
  ): void;
};

/**
 * In-memory multer storage (same behavior as `memoryStorage()` from multer).
 */
export function createMulterMemoryStorage(): MulterLikeStorageEngine {
  return {
    _handleFile(
      _req: unknown,
      file: MulterMemoryUploadedFile,
      cb: (
        error?: Error | null,
        info?: Partial<MulterMemoryUploadedFile>,
      ) => void,
    ): void {
      const chunks: Buffer[] = [];
      const stream = file.stream as Readable;
      stream.on('data', (chunk: Buffer) => {
        chunks.push(chunk);
      });
      stream.on('end', () => {
        const buffer = Buffer.concat(chunks);
        cb(null, { buffer, size: buffer.length });
      });
      stream.on('error', (err: Error) => {
        cb(err);
      });
    },
    _removeFile(
      _req: unknown,
      file: MulterMemoryUploadedFile,
      cb: (error: Error | null) => void,
    ): void {
      Reflect.deleteProperty(file as object, 'buffer');
      cb(null);
    },
  };
}
