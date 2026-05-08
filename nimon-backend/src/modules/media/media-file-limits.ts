const DEFAULT_COVER_MAX = 10 * 1024 * 1024;
const DEFAULT_AUDIO_MAX = 50 * 1024 * 1024;

/**
 * Read at module / process level so FileInterceptor and MediaService share limits.
 */
export function readCoverMaxBytesFromEnv(): number {
  const v = process.env.MEDIA_COVER_MAX_BYTES;
  const n = v != null && v !== '' ? Number(v) : NaN;
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : DEFAULT_COVER_MAX;
}

export function readAudioMaxBytesFromEnv(): number {
  const v = process.env.MEDIA_AUDIO_MAX_BYTES;
  const n = v != null && v !== '' ? Number(v) : NaN;
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : DEFAULT_AUDIO_MAX;
}
