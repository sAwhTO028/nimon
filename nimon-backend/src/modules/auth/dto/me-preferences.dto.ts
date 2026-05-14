import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, ValidateIf } from 'class-validator';

function trimOrNull(v: unknown): string | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  const s = typeof v === 'string' ? v : String(v);
  const t = s.trim();
  return t === '' ? null : t;
}

export const APP_LOCALES = ['system', 'en', 'ja', 'my'] as const;
export type AppLocale = (typeof APP_LOCALES)[number];

export const CONTENT_LOCALES = ['my', 'en', 'ja'] as const;
export type ContentLocale = (typeof CONTENT_LOCALES)[number];

export const LEARNING_LANGUAGES = ['ja'] as const;
export type LearningLanguage = (typeof LEARNING_LANGUAGES)[number];

export const THEME_MODES = ['system', 'light', 'dark'] as const;
export type ThemeMode = (typeof THEME_MODES)[number];

export const READING_TEXT_SIZES = ['small', 'standard', 'large'] as const;
export type ReadingTextSize = (typeof READING_TEXT_SIZES)[number];

export const DEFAULT_ME_PREFERENCES = {
  appLocale: 'system' as AppLocale,
  contentLocale: 'en' as ContentLocale,
  learningLanguage: 'ja' as LearningLanguage,
  themeMode: 'system' as ThemeMode,
  readingTextSize: 'standard' as ReadingTextSize,
  showExplanations: true,
};

export class PatchMePreferencesDto {
  @IsOptional()
  @Transform(({ value }) => trimOrNull(value))
  @ValidateIf((_, v) => v !== null)
  @IsIn(APP_LOCALES, { message: 'appLocale_invalid' })
  appLocale?: AppLocale | null;

  @IsOptional()
  @Transform(({ value }) => trimOrNull(value))
  @ValidateIf((_, v) => v !== null)
  @IsIn(CONTENT_LOCALES, { message: 'contentLocale_invalid' })
  contentLocale?: ContentLocale | null;

  @IsOptional()
  @Transform(({ value }) => trimOrNull(value))
  @ValidateIf((_, v) => v !== null)
  @IsIn(LEARNING_LANGUAGES, { message: 'learningLanguage_invalid' })
  learningLanguage?: LearningLanguage | null;

  @IsOptional()
  @Transform(({ value }) => trimOrNull(value))
  @ValidateIf((_, v) => v !== null)
  @IsIn(THEME_MODES, { message: 'themeMode_invalid' })
  themeMode?: ThemeMode | null;

  @IsOptional()
  @Transform(({ value }) => trimOrNull(value))
  @ValidateIf((_, v) => v !== null)
  @IsIn(READING_TEXT_SIZES, { message: 'readingTextSize_invalid' })
  readingTextSize?: ReadingTextSize | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsBoolean({ message: 'showExplanations_invalid' })
  showExplanations?: boolean | null;
}

export type MePreferencesResponseDto = {
  appLocale: AppLocale;
  contentLocale: ContentLocale;
  learningLanguage: LearningLanguage;
  themeMode: ThemeMode;
  readingTextSize: ReadingTextSize;
  showExplanations: boolean;
};

