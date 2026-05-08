/**
 * Injection token for {@link MediaStorage} (disk today; S3/R2 in M6c).
 */
export const MEDIA_STORAGE = Symbol('MEDIA_STORAGE');

export type MediaStorageSaveParams = {
  userId: string;
  kind: 'cover' | 'audio';
  buffer: Buffer;
  /** Leading dot, e.g. `.jpg` — from validated MIME mapping in {@link MediaService}. */
  extension: string;
  /** Canonical lowercase MIME (e.g. `image/jpeg`). */
  mediaType: string;
};

export type MediaStorageSaveResult = {
  /** Relative object key / path segments (unencoded), e.g. `<userId>/cover/<file>.jpg`. */
  key: string;
  /** Full public HTTPS (or dev HTTP) URL for clients. */
  url: string;
};

export interface MediaStorage {
  save(params: MediaStorageSaveParams): Promise<MediaStorageSaveResult>;
}
