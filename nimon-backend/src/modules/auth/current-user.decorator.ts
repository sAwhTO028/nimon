import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import type { JwtValidatedUser } from './jwt.strategy';

/**
 * Resolved user from {@link JwtOrDevOwnerFallbackGuard} / JWT validation.
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtValidatedUser => {
    const req = ctx.switchToHttp().getRequest<{ user?: JwtValidatedUser }>();
    const u = req.user;
    if (!u?.userId) {
      throw new UnauthorizedException();
    }
    return u;
  },
);
