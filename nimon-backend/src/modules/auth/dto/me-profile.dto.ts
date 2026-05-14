import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  MaxLength,
} from 'class-validator';

function trimOrNull(v: unknown): string | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  const s = typeof v === 'string' ? v : String(v);
  const t = s.trim();
  return t === '' ? null : t;
}

function normalizeHandle(v: unknown): string | null | undefined {
  const t = trimOrNull(v);
  if (t === undefined || t === null) return t;
  const raw = t.startsWith('@') ? t.substring(1) : t;
  const out = raw.trim().toLowerCase();
  return out === '' ? null : out;
}

export class PatchMeProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(30)
  @Transform(({ value }) => trimOrNull(value))
  displayName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  @Matches(/^[a-z0-9_.]{3,24}$/, { message: 'handle_invalid' })
  @Transform(({ value }) => normalizeHandle(value))
  handle?: string | null;

  @IsOptional()
  @IsString()
  @IsUrl({
    require_protocol: true,
    protocols: ['http', 'https'],
    require_tld: false,
  })
  @Transform(({ value }) => trimOrNull(value))
  avatarUrl?: string | null;

  @IsOptional()
  @IsString()
  @IsUrl({
    require_protocol: true,
    protocols: ['http', 'https'],
    require_tld: false,
  })
  @Transform(({ value }) => trimOrNull(value))
  coverImageUrl?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  @Transform(({ value }) => trimOrNull(value))
  bio?: string | null;
}

export type MeProfileResponseDto = {
  user: {
    id: string;
    email: string | null;
  };
  profile: {
    displayName: string | null;
    handle: string | null;
    avatarUrl: string | null;
    coverImageUrl: string | null;
    bio: string | null;
  } | null;
};

