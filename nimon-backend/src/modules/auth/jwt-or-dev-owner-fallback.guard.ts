import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { ExtractJwt } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';
import { resolveJwtSecret } from './auth.config';
import { DEFAULT_DEV_OWNER_ID } from './dev-owner.constants';
import type { JwtValidatedUser } from './jwt.strategy';

/**
 * Requires a valid Bearer JWT that maps to an existing `User`, **unless**
 * `NODE_ENV !== 'production'` **and** `ALLOW_DEV_OWNER_FALLBACK=true`, in which case
 * requests **without** `Authorization` are treated as the dev owner (`DEV_OWNER_ID`
 * or {@link DEFAULT_DEV_OWNER_ID}). Never enables fallback in production.
 */
@Injectable()
export class JwtOrDevOwnerFallbackGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<
        Request & {
          user?: JwtValidatedUser;
        }
      >();
    const token = ExtractJwt.fromAuthHeaderAsBearerToken()(req);

    if (token) {
      try {
        const secret = resolveJwtSecret(this.config);
        const payload = this.jwt.verify<{ sub?: string }>(token, { secret });
        const sub = payload.sub;
        if (!sub || typeof sub !== 'string') {
          throw new UnauthorizedException();
        }
        const user = await this.prisma.user.findUnique({
          where: { id: sub },
          select: { id: true, email: true },
        });
        if (!user) {
          throw new UnauthorizedException();
        }
        req.user = { userId: user.id, email: user.email };
        return true;
      } catch {
        throw new UnauthorizedException();
      }
    }

    const nodeEnv =
      this.config.get<string>('NODE_ENV') ??
      process.env.NODE_ENV ??
      'development';
    const allowFallbackRaw =
      this.config.get<string>('ALLOW_DEV_OWNER_FALLBACK') ??
      process.env.ALLOW_DEV_OWNER_FALLBACK;
    const allowFallback = allowFallbackRaw === 'true';

    if (nodeEnv !== 'production' && allowFallback) {
      const ownerId =
        this.config.get<string>('DEV_OWNER_ID') ??
        process.env.DEV_OWNER_ID ??
        DEFAULT_DEV_OWNER_ID;
      req.user = { userId: ownerId, email: null };
      return true;
    }

    throw new UnauthorizedException();
  }
}
