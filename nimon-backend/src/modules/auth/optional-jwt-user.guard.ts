import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { ExtractJwt } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';
import { resolveJwtSecret } from './auth.config';
import type { JwtValidatedUser } from './jwt.strategy';

/**
 * Public endpoints: if a valid Bearer JWT is present, attach `req.user`.
 * If absent or invalid, allow request as guest (no 401).
 */
@Injectable()
export class OptionalJwtUserGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<Request & { user?: JwtValidatedUser }>();

    const token = ExtractJwt.fromAuthHeaderAsBearerToken()(req);
    if (!token) return true;

    try {
      const secret = resolveJwtSecret(this.config);
      const payload = this.jwt.verify<{ sub?: string }>(token, { secret });
      const sub = payload.sub;
      if (!sub || typeof sub !== 'string') {
        return true;
      }
      const user = await this.prisma.user.findUnique({
        where: { id: sub },
        select: { id: true, email: true },
      });
      if (!user) return true;
      req.user = { userId: user.id, email: user.email };
      return true;
    } catch {
      return true;
    }
  }
}

