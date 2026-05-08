import type { Request } from 'express';

import type { JwtValidatedUser } from './jwt.strategy';

/** Request after {@link JwtOrDevOwnerFallbackGuard} attaches `user` from JWT `sub`. */
export type AuthenticatedRequest = Request & { user: JwtValidatedUser };
