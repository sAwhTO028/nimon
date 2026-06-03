import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { resolveRefreshExpiresSeconds } from './auth.config';
import { assertNoBlockingValidationIssues } from '../../common/validation/validation-exception';
import { combine } from '../../common/validation/validation-result';
import {
  normalizeEmailInput,
  validateLoginPayload,
  validateRegisterPayload,
} from '../../common/validation/auth-validation';
import {
  validateProfileBio,
  validateProfileDisplayName,
  validateProfileHandle,
} from '../../common/validation/profile-validation';
import {
  assertDistinctLanguagePair,
  safeV1ContentLocale,
  safeV1LearningLanguage,
} from '../../common/validation/language-pair-validation';
import {
  DEFAULT_ME_PREFERENCES,
  READING_TEXT_SIZES,
  type ContentLocale,
  type LearningLanguage,
  type MePreferencesResponseDto,
  type PatchMePreferencesDto,
  type ReadingTextSize,
} from './dto/me-preferences.dto';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  tokenType: 'Bearer';
}

export interface MeResponse {
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
    createdAt: string;
    updatedAt: string;
  } | null;
}

const BCRYPT_COST = 12;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly media: MediaUrlCanonicalizerService,
  ) {}

  private hashRefreshOpaque(token: string): string {
    return createHash('sha256').update(token, 'utf8').digest('hex');
  }

  private newOpaqueRefreshToken(): string {
    return randomBytes(48).toString('base64url');
  }

  private async signAccessToken(
    userId: string,
    email: string | null,
  ): Promise<string> {
    return this.jwt.signAsync({ sub: userId, email });
  }

  async register(dto: RegisterDto): Promise<AuthTokens> {
    const regVal = validateRegisterPayload({
      email: dto.email,
      password: dto.password,
    });
    assertNoBlockingValidationIssues(regVal);

    const email = normalizeEmailInput(dto.email);
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = bcrypt.hashSync(dto.password, BCRYPT_COST);
    const displayName = email.includes('@')
      ? email.slice(0, email.indexOf('@'))
      : email;

    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            email,
            passwordHash,
          },
        });

        await tx.userProfile.create({
          data: {
            userId: user.id,
            displayName,
            handle: null,
          },
        });

        const refreshPlain = this.newOpaqueRefreshToken();
        const refreshSeconds = resolveRefreshExpiresSeconds(this.config);
        const expiresAt = new Date(Date.now() + refreshSeconds * 1000);

        await tx.refreshToken.create({
          data: {
            userId: user.id,
            tokenHash: this.hashRefreshOpaque(refreshPlain),
            expiresAt,
          },
        });

        return { user, refreshPlain };
      });

      const accessToken = await this.signAccessToken(
        result.user.id,
        result.user.email,
      );

      return {
        accessToken,
        refreshToken: result.refreshPlain,
        tokenType: 'Bearer',
      };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('Email already registered');
      }
      throw e;
    }
  }

  async login(dto: LoginDto): Promise<AuthTokens> {
    const loginVal = validateLoginPayload({
      email: dto.email,
      password: dto.password,
    });
    assertNoBlockingValidationIssues(loginVal);

    const email = normalizeEmailInput(dto.email);
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user?.passwordHash) {
      throw new UnauthorizedException('Email or password is incorrect.');
    }

    const ok = bcrypt.compareSync(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Email or password is incorrect.');
    }

    await this.prisma.refreshToken.updateMany({
      where: {
        userId: user.id,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      data: { revokedAt: new Date() },
    });

    const refreshPlain = this.newOpaqueRefreshToken();
    const refreshSeconds = resolveRefreshExpiresSeconds(this.config);
    const expiresAt = new Date(Date.now() + refreshSeconds * 1000);

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.hashRefreshOpaque(refreshPlain),
        expiresAt,
      },
    });

    const accessToken = await this.signAccessToken(user.id, user.email);

    return {
      accessToken,
      refreshToken: refreshPlain,
      tokenType: 'Bearer',
    };
  }

  /**
   * Rotates the opaque refresh token: revokes the presented row, inserts a new
   * `RefreshToken` row, and returns a new access JWT + new plaintext refresh.
   *
   * **Reuse:** A row found by hash with `revokedAt` set (e.g. post-rotation or
   * logout) is treated as a reuse signal — all still-valid refresh rows for that
   * user are revoked, then `UnauthorizedException` is thrown (same message as
   * unknown/expired tokens; no extra detail).
   */
  async refresh(refreshTokenPlain: string): Promise<AuthTokens> {
    const tokenHash = this.hashRefreshOpaque(refreshTokenPlain);
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!row) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const now = new Date();

    if (row.revokedAt != null) {
      await this.revokeAllActiveRefreshTokensForUser(row.userId, now);
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (row.expiresAt.getTime() <= now.getTime()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: row.userId },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const refreshSeconds = resolveRefreshExpiresSeconds(this.config);
    const newExpiresAt = new Date(Date.now() + refreshSeconds * 1000);
    const newPlain = this.newOpaqueRefreshToken();
    const newHash = this.hashRefreshOpaque(newPlain);

    await this.prisma.$transaction(async (tx) => {
      const cur = await tx.refreshToken.findUnique({
        where: { tokenHash },
      });
      if (
        !cur ||
        cur.revokedAt != null ||
        cur.expiresAt.getTime() <= Date.now()
      ) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      await tx.refreshToken.update({
        where: { tokenHash },
        data: { revokedAt: new Date() },
      });
      await tx.refreshToken.create({
        data: {
          userId: cur.userId,
          tokenHash: newHash,
          expiresAt: newExpiresAt,
        },
      });
    });

    const accessToken = await this.signAccessToken(user.id, user.email);

    return {
      accessToken,
      refreshToken: newPlain,
      tokenType: 'Bearer',
    };
  }

  /** Revokes all non-expired, non-revoked refresh tokens for a user (session kill). */
  private async revokeAllActiveRefreshTokensForUser(
    userId: string,
    at: Date,
  ): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: at },
      },
      data: { revokedAt: at },
    });
  }

  /**
   * Idempotent: unknown hash or already-revoked row updates 0 rows; no error.
   */
  async logout(refreshTokenPlain: string): Promise<void> {
    const tokenHash = this.hashRefreshOpaque(refreshTokenPlain);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async getMe(userId: string): Promise<MeResponse> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });

    if (!user) {
      throw new UnauthorizedException();
    }

    const p = user.profile;
    return {
      user: {
        id: user.id,
        email: user.email,
      },
      profile: p
        ? {
            displayName: p.displayName,
            handle: p.handle,
            avatarUrl: this.media.url(p.avatarUrl),
            coverImageUrl: this.media.url((p as any).coverImageUrl ?? null),
            bio: p.bio,
            createdAt: p.createdAt.toISOString(),
            updatedAt: p.updatedAt.toISOString(),
          }
        : null,
    };
  }

  async getMeProfile(
    userId: string,
  ): Promise<import('./dto/me-profile.dto').MeProfileResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) {
      throw new UnauthorizedException();
    }
    const p = user.profile;
    return {
      user: { id: user.id, email: user.email },
      profile: p
        ? {
            displayName: p.displayName,
            handle: p.handle,
            avatarUrl: this.media.url(p.avatarUrl),
            coverImageUrl: this.media.url((p as any).coverImageUrl ?? null),
            bio: p.bio,
          }
        : null,
    };
  }

  async patchMeProfile(
    userId: string,
    dto: import('./dto/me-profile.dto').PatchMeProfileDto,
  ): Promise<import('./dto/me-profile.dto').MeProfileResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true },
    });
    if (!user) {
      throw new UnauthorizedException();
    }

    const profileValidation = combine(
      ...(dto.displayName !== undefined
        ? [validateProfileDisplayName(dto.displayName)]
        : []),
      ...(dto.handle !== undefined ? [validateProfileHandle(dto.handle)] : []),
      ...(dto.bio !== undefined ? [validateProfileBio(dto.bio)] : []),
    );
    assertNoBlockingValidationIssues(profileValidation);

    const data: Record<string, unknown> = {};
    if (dto.displayName !== undefined) data.displayName = dto.displayName;
    if (dto.handle !== undefined) data.handle = dto.handle;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.coverImageUrl !== undefined) data.coverImageUrl = dto.coverImageUrl;
    if (dto.bio !== undefined) data.bio = dto.bio;

    try {
      const profile = await this.prisma.userProfile.upsert({
        where: { userId },
        create: {
          userId,
          displayName: (dto.displayName ?? null) as any,
          handle: (dto.handle ?? null) as any,
          avatarUrl: (dto.avatarUrl ?? null) as any,
          coverImageUrl: (dto.coverImageUrl ?? null) as any,
          bio: (dto.bio ?? null) as any,
        },
        update: data as any,
      });
      return {
        user: { id: user.id, email: user.email },
        profile: {
          displayName: profile.displayName,
          handle: profile.handle,
          avatarUrl: this.media.url(profile.avatarUrl),
          coverImageUrl: this.media.url((profile as any).coverImageUrl ?? null),
          bio: profile.bio,
        },
      };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const target = (e.meta as any)?.target;
        const hasHandle = Array.isArray(target)
          ? target.includes('handle')
          : String(target ?? '').includes('handle');
        if (hasHandle) {
          throw new ConflictException({
            code: 'handle_taken',
            message: 'That handle is taken.',
          } as any);
        }
      }
      throw e;
    }
  }

  private resolvePreference<T extends string>(
    v: string | null | undefined,
    defaultValue: T,
    opts?: { treatDefaultStringAsNull?: T },
  ): T {
    const t = typeof v === 'string' ? v.trim() : '';
    if (!t) return defaultValue;
    if (opts?.treatDefaultStringAsNull && t === opts.treatDefaultStringAsNull) {
      return defaultValue;
    }
    return t as T;
  }

  private sanitizeReadingTextSize(raw: string): ReadingTextSize {
    return (READING_TEXT_SIZES as readonly string[]).includes(raw)
      ? (raw as ReadingTextSize)
      : DEFAULT_ME_PREFERENCES.readingTextSize;
  }

  private storePreference(
    v: string | null,
    defaultValue: string,
    opts?: { defaultAlias?: string },
  ): string | null {
    if (v == null) return null;
    const t = String(v).trim();
    if (!t) return null;
    if (t === defaultValue) return null;
    if (opts?.defaultAlias && t === opts.defaultAlias) return null;
    return t;
  }

  async getMePreferences(userId: string): Promise<MePreferencesResponseDto> {
    const row = await this.prisma.userPreference.findUnique({
      where: { userId },
      select: {
        appLocale: true,
        contentLocale: true,
        learningLanguage: true,
        themeMode: true,
        readingTextSize: true,
        showExplanations: true,
      },
    });

    if (!row) return { ...DEFAULT_ME_PREFERENCES };

    return {
      appLocale: this.resolvePreference(row.appLocale, DEFAULT_ME_PREFERENCES.appLocale, {
        treatDefaultStringAsNull: 'system',
      }),
      contentLocale: this.resolvePreference(row.contentLocale, DEFAULT_ME_PREFERENCES.contentLocale),
      learningLanguage: this.resolvePreference(
        row.learningLanguage,
        DEFAULT_ME_PREFERENCES.learningLanguage,
      ),
      themeMode: this.resolvePreference(row.themeMode, DEFAULT_ME_PREFERENCES.themeMode, {
        treatDefaultStringAsNull: 'system',
      }),
      readingTextSize: this.sanitizeReadingTextSize(
        this.resolvePreference(row.readingTextSize, DEFAULT_ME_PREFERENCES.readingTextSize, {
          treatDefaultStringAsNull: 'standard',
        }),
      ),
      showExplanations: row.showExplanations ?? DEFAULT_ME_PREFERENCES.showExplanations,
    };
  }

  async patchMePreferences(
    userId: string,
    dto: PatchMePreferencesDto,
  ): Promise<MePreferencesResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      throw new UnauthorizedException();
    }

    const data: Record<string, unknown> = {};
    if (dto.appLocale !== undefined) {
      data.appLocale = this.storePreference(dto.appLocale, DEFAULT_ME_PREFERENCES.appLocale, {
        defaultAlias: 'system',
      });
    }
    if (dto.contentLocale !== undefined) {
      data.contentLocale = this.storePreference(
        dto.contentLocale,
        DEFAULT_ME_PREFERENCES.contentLocale,
      );
    }
    if (dto.learningLanguage !== undefined) {
      data.learningLanguage = this.storePreference(
        dto.learningLanguage,
        DEFAULT_ME_PREFERENCES.learningLanguage,
      );
    }
    if (dto.themeMode !== undefined) {
      data.themeMode = this.storePreference(dto.themeMode, DEFAULT_ME_PREFERENCES.themeMode, {
        defaultAlias: 'system',
      });
    }
    if (dto.readingTextSize !== undefined) {
      data.readingTextSize = this.storePreference(
        dto.readingTextSize,
        DEFAULT_ME_PREFERENCES.readingTextSize,
        { defaultAlias: 'standard' },
      );
    }
    if (dto.showExplanations !== undefined) {
      if (dto.showExplanations === null || dto.showExplanations === true) {
        data.showExplanations = null;
      } else {
        data.showExplanations = false;
      }
    }

    const current = await this.getMePreferences(userId);
    let nextContent: ContentLocale = current.contentLocale;
    let nextLearning: LearningLanguage = current.learningLanguage;
    if (dto.contentLocale !== undefined) {
      nextContent =
        dto.contentLocale === null
          ? DEFAULT_ME_PREFERENCES.contentLocale
          : dto.contentLocale;
    }
    if (dto.learningLanguage !== undefined) {
      nextLearning =
        dto.learningLanguage === null
          ? DEFAULT_ME_PREFERENCES.learningLanguage
          : dto.learningLanguage;
    }
    try {
      assertDistinctLanguagePair(
        safeV1ContentLocale(nextContent),
        safeV1LearningLanguage(nextLearning),
      );
    } catch (e) {
      if (e instanceof BadRequestException) {
        throw new BadRequestException('language_pair_same_not_allowed');
      }
      throw e;
    }

    const out = await this.prisma.userPreference.upsert({
      where: { userId },
      create: {
        userId,
        appLocale:
          dto.appLocale === undefined
            ? null
            : (this.storePreference(dto.appLocale, DEFAULT_ME_PREFERENCES.appLocale, {
                defaultAlias: 'system',
              }) as any),
        contentLocale:
          dto.contentLocale === undefined
            ? null
            : (this.storePreference(dto.contentLocale, DEFAULT_ME_PREFERENCES.contentLocale) as any),
        learningLanguage:
          dto.learningLanguage === undefined
            ? null
            : (this.storePreference(
                dto.learningLanguage,
                DEFAULT_ME_PREFERENCES.learningLanguage,
              ) as any),
        themeMode:
          dto.themeMode === undefined
            ? null
            : (this.storePreference(dto.themeMode, DEFAULT_ME_PREFERENCES.themeMode, {
                defaultAlias: 'system',
              }) as any),
        readingTextSize:
          dto.readingTextSize === undefined
            ? null
            : (this.storePreference(dto.readingTextSize, DEFAULT_ME_PREFERENCES.readingTextSize, {
                defaultAlias: 'standard',
              }) as any),
        showExplanations:
          dto.showExplanations === undefined
            ? null
            : dto.showExplanations === null || dto.showExplanations === true
              ? null
              : false,
      },
      update: data as any,
      select: {
        appLocale: true,
        contentLocale: true,
        learningLanguage: true,
        themeMode: true,
        readingTextSize: true,
        showExplanations: true,
      },
    });

    return {
      appLocale: this.resolvePreference(out.appLocale, DEFAULT_ME_PREFERENCES.appLocale, {
        treatDefaultStringAsNull: 'system',
      }),
      contentLocale: this.resolvePreference(out.contentLocale, DEFAULT_ME_PREFERENCES.contentLocale),
      learningLanguage: this.resolvePreference(
        out.learningLanguage,
        DEFAULT_ME_PREFERENCES.learningLanguage,
      ),
      themeMode: this.resolvePreference(out.themeMode, DEFAULT_ME_PREFERENCES.themeMode, {
        treatDefaultStringAsNull: 'system',
      }),
      readingTextSize: this.sanitizeReadingTextSize(
        this.resolvePreference(out.readingTextSize, DEFAULT_ME_PREFERENCES.readingTextSize, {
          treatDefaultStringAsNull: 'standard',
        }),
      ),
      showExplanations: out.showExplanations ?? DEFAULT_ME_PREFERENCES.showExplanations,
    };
  }
}
