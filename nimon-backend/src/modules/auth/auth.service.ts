import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { resolveRefreshExpiresSeconds } from './auth.config';

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
    const email = dto.email;
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
    const email = dto.email;
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const ok = bcrypt.compareSync(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
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

  async refresh(refreshTokenPlain: string): Promise<AuthTokens> {
    const tokenHash = this.hashRefreshOpaque(refreshTokenPlain);
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (
      !row ||
      row.revokedAt != null ||
      row.expiresAt.getTime() <= Date.now()
    ) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: row.userId },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const accessToken = await this.signAccessToken(user.id, user.email);

    return {
      accessToken,
      refreshToken: refreshTokenPlain,
      tokenType: 'Bearer',
    };
  }

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
            avatarUrl: p.avatarUrl,
            coverImageUrl: (p as any).coverImageUrl ?? null,
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
            avatarUrl: p.avatarUrl,
            coverImageUrl: (p as any).coverImageUrl ?? null,
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
          avatarUrl: profile.avatarUrl,
          coverImageUrl: (profile as any).coverImageUrl ?? null,
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
}
