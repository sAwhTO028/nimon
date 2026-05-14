/** Trim leading/trailing whitespace; treat null/undefined as empty string. */
export function trimText(value: string | null | undefined): string {
  if (value == null) return '';
  return String(value).trim();
}

/** Collapse internal runs of whitespace to a single space (does not trim ends). */
export function collapseSpaces(value: string): string {
  return value.replace(/\s+/g, ' ');
}

/** Trim, collapse spaces, remove line breaks as spaces for single-line fields. */
export function normalizeSingleLineText(value: string): string {
  const t = trimText(value);
  const noBreaks = t.replace(/[\r\n]+/g, ' ');
  return collapseSpaces(noBreaks).trim();
}

const SCRIPTISH =
  /<\/|\/?script|javascript:|on\w+\s*=|<iframe|<object|<embed|<svg[\s\S]*on/i;

export function containsHtmlOrScript(value: string): boolean {
  if (!value) return false;
  if (SCRIPTISH.test(value)) return true;
  if (/<[a-z][\s\S]*>/i.test(value)) return true;
  return false;
}

const URL_PATTERN =
  '(?:https?:\\/\\/|www\\.)[^\\s]+|[a-z0-9][a-z0-9-]*\\.[a-z]{2,}\\b[^\\s]*';

export function containsUrl(value: string): boolean {
  if (!value) return false;
  return new RegExp(URL_PATTERN, 'gi').test(value);
}

/** Rough emoji count (extended pictographic + keycap sequences). */
export function countEmojis(value: string): number {
  if (!value) return 0;
  const re = /\p{Extended_Pictographic}/gu;
  const m = value.match(re);
  return m?.length ?? 0;
}

export function isOnlyNumbers(value: string): boolean {
  const t = trimText(value);
  if (!t) return false;
  return /^[0-9０-９]+$/.test(t);
}

/** Letters/numbers only → not "only symbols"; this flags symbol-only noise. */
export function isOnlySymbols(value: string): boolean {
  const t = trimText(value);
  if (!t) return false;
  if (/[\p{L}\p{N}]/u.test(t)) return false;
  return /^[\p{S}\p{P}\s]+$/u.test(t);
}

export function hasExcessiveRepeatedCharacters(
  value: string,
  maxRepeat = 4,
): boolean {
  if (!value || maxRepeat < 2) return false;
  const re = new RegExp(`(.)\\1{${maxRepeat},}`, 'u');
  return re.test(value);
}

export function countLines(value: string): number {
  if (!trimText(value)) return 0;
  const parts = value.split(/\r\n|\r|\n/);
  return parts.length;
}

/** Unicode code-point length (better than UTF-16 .length for many scripts). */
export function charLength(value: string): number {
  return [...value].length;
}

export function countUrls(value: string): number {
  if (!value) return 0;
  const m = value.match(new RegExp(URL_PATTERN, 'gi'));
  return m?.length ?? 0;
}

export function countHashtags(value: string): number {
  if (!value) return 0;
  const m = value.match(/#[\p{L}\p{N}_]+/gu);
  return m?.length ?? 0;
}
