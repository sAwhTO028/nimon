import type { JlptLevel, StoryDurationBand } from './story-validation';

const BANDS: ReadonlySet<string> = new Set(['3_5', '5_7', '7_9']);

/**
 * Resolves target duration band for publish validation.
 *
 * - Prefer explicit `targetDurationBandKey` when it matches product keys (`3_5`, `5_7`, `7_9`).
 * - If missing, infer from `durationSeconds` when present (creator V1 manual duration):
 *   - 3 ≤ min < 5 → `3_5`
 *   - 5 ≤ min < 7 → `5_7`
 *   - 7 ≤ min ≤ 9 → `7_9`
 * - Otherwise return `null` — JLPT×band sentence/vocab limits are **skipped** (no blocking),
 *   matching M13B “do not block old flow” when duration was never collected.
 */
export function resolveStoryDurationBand(input: {
  targetDurationBandKey?: string | null;
  /** Draft basics optional manual duration (seconds); not always persisted server-side. */
  durationSeconds?: number | null;
}): StoryDurationBand | null {
  const raw = input.targetDurationBandKey?.trim();
  if (raw && BANDS.has(raw)) {
    return raw as StoryDurationBand;
  }

  const sec = input.durationSeconds;
  if (sec == null || !Number.isFinite(sec) || sec <= 0) {
    return null;
  }
  const minutes = sec / 60;
  if (minutes >= 3 && minutes < 5) return '3_5';
  if (minutes >= 5 && minutes < 7) return '5_7';
  if (minutes >= 7 && minutes <= 9) return '7_9';
  return null;
}

export function normalizeJlptLevel(levelRaw: string | null | undefined): JlptLevel | null {
  const s = (levelRaw ?? '').trim().toLowerCase();
  if (!s) return null;
  if (s.includes('n1') || s === 'n1') return 'N1';
  if (s.includes('n2') || s === 'n2') return 'N2';
  if (s.includes('n3') || s === 'n3') return 'N3';
  if (s.includes('n4') || s === 'n4') return 'N4';
  if (s.includes('n5') || s === 'n5') return 'N5';
  return null;
}
