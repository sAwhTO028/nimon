import { extname } from 'node:path';
import { UnsupportedMediaTypeException } from '@nestjs/common';
import { throwValidationFailed } from '../../common/validation/validation-exception';
import {
  issueMediaFileEmpty,
  issueMediaFileRequired,
} from '../../common/validation/media-validation';
import type { MulterMemoryUploadedFile } from './media-upload.types';

const OCTET_STREAM = 'application/octet-stream';

/** Canonical cover MIME types returned to clients and used for storage mapping. */
const COVER_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

/** Non-canonical aliases normalized before validation (e.g. Chrome / Flutter). */
const COVER_MIME_ALIASES = new Map<string, string>([
  ['image/jpg', 'image/jpeg'],
]);

/** Canonical audio MIME returned to clients (Flutter/file picker variance normalized here). */
export const CANONICAL_AUDIO_MPEG = 'audio/mpeg';
export const CANONICAL_AUDIO_MP4 = 'audio/mp4';
export const CANONICAL_AUDIO_WAV = 'audio/wav';

/** Declared Content-Type → canonical (browser / Flutter web often sends aliases or octet-stream). */
const AUDIO_DECLARED_TO_CANONICAL = new Map<string, string>([
  ['audio/mpeg', CANONICAL_AUDIO_MPEG],
  ['audio/mp3', CANONICAL_AUDIO_MPEG],
  ['audio/mp4', CANONICAL_AUDIO_MP4],
  ['audio/x-m4a', CANONICAL_AUDIO_MP4],
  ['audio/m4a', CANONICAL_AUDIO_MP4],
  ['audio/wav', CANONICAL_AUDIO_WAV],
  ['audio/x-wav', CANONICAL_AUDIO_WAV],
  ['audio/wave', CANONICAL_AUDIO_WAV],
  ['audio/vnd.wave', CANONICAL_AUDIO_WAV],
]);

/** Extensions never accepted when inferring from filename (octet-stream / empty type). */
const AUDIO_BLOCKED_EXTENSIONS = new Set([
  '.pdf',
  '.txt',
  '.exe',
  '.aac',
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
]);

export type MediaKind = 'cover' | 'audio';

export function sanitizeOriginalFilename(name: string): string {
  const base = name.replace(/^.*[/\\]/, '').trim();
  const cleaned = base.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(0, 128);
  return cleaned.length > 0 ? cleaned : 'upload.bin';
}

function canonicalCoverMimeFromDeclared(mimetype: string): string | null {
  const lower = mimetype.trim().toLowerCase();
  if (COVER_MIME_ALIASES.has(lower)) {
    return COVER_MIME_ALIASES.get(lower)!;
  }
  if (COVER_MIME_TYPES.has(lower)) {
    return lower;
  }
  return null;
}

function canonicalCoverMimeFromExtension(extLower: string): string | null {
  switch (extLower) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    default:
      return null;
  }
}

/**
 * Resolves and validates cover MIME: accepts image/jpeg, image/jpg, image/png, image/webp,
 * and when multer reports {@link OCTET_STREAM} or an empty type, infers from
 * {@link sanitizeOriginalFilename} extension (.jpg / .jpeg / .png / .webp only).
 *
 * @returns Canonical MIME: image/jpeg, image/png, or image/webp (never image/jpg).
 */
export function resolveCoverMime(
  mimetype: string | undefined,
  originalname: string | undefined,
): string {
  const raw = (mimetype ?? '').trim().toLowerCase();

  if (raw && raw !== OCTET_STREAM) {
    const canonical = canonicalCoverMimeFromDeclared(raw);
    if (canonical) {
      return canonical;
    }
    throw new UnsupportedMediaTypeException(
      'Cover must be image/jpeg, image/jpg, image/png, or image/webp.',
    );
  }

  const safeName = sanitizeOriginalFilename(originalname ?? '');
  const ext = extname(safeName).toLowerCase();
  const fromExt = canonicalCoverMimeFromExtension(ext);
  if (!fromExt) {
    throw new UnsupportedMediaTypeException(
      'Cover must be image/jpeg, image/png, or image/webp (or a matching .jpg / .jpeg / .png / .webp filename when the browser sends an unknown type).',
    );
  }
  return fromExt;
}

function canonicalAudioMimeFromExtension(extLower: string): string | null {
  switch (extLower) {
    case '.mp3':
      return CANONICAL_AUDIO_MPEG;
    case '.m4a':
      return CANONICAL_AUDIO_MP4;
    case '.wav':
      return CANONICAL_AUDIO_WAV;
    default:
      return null;
  }
}

/**
 * Resolves audio MIME like {@link resolveCoverMime}: maps practical variants to canonical
 * {@link CANONICAL_AUDIO_MPEG}, {@link CANONICAL_AUDIO_MP4}, {@link CANONICAL_AUDIO_WAV};
 * for empty type or `application/octet-stream`, infers from sanitized filename extension.
 */
export function resolveAudioMime(
  mimetype: string | undefined,
  originalname: string | undefined,
): string {
  const raw = (mimetype ?? '').trim().toLowerCase();

  if (raw && raw !== OCTET_STREAM) {
    const canonical = AUDIO_DECLARED_TO_CANONICAL.get(raw);
    if (canonical) {
      return canonical;
    }
    throw new UnsupportedMediaTypeException(
      'Audio must be mp3, m4a, or wav (supported Content-Types include audio/mpeg, audio/mp4, audio/wav, and common aliases).',
    );
  }

  const safeName = sanitizeOriginalFilename(originalname ?? '');
  const ext = extname(safeName).toLowerCase();

  if (AUDIO_BLOCKED_EXTENSIONS.has(ext)) {
    throw new UnsupportedMediaTypeException(
      'Audio must be a .mp3, .m4a, or .wav file (unsupported extension).',
    );
  }

  const fromExt = canonicalAudioMimeFromExtension(ext);
  if (!fromExt) {
    throw new UnsupportedMediaTypeException(
      'Audio must be mp3, m4a, or wav (or a matching .mp3 / .m4a / .wav filename when the browser sends an unknown type).',
    );
  }
  return fromExt;
}

export function assertFilePresent(
  file: MulterMemoryUploadedFile | undefined,
): asserts file is MulterMemoryUploadedFile {
  if (!file) {
    throwValidationFailed([issueMediaFileRequired()]);
  }
  if (!Buffer.isBuffer(file.buffer) || file.buffer.length === 0) {
    throwValidationFailed([issueMediaFileEmpty()]);
  }
}
