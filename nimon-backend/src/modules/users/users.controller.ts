import { Controller, Get, Header, Param, Req, UseGuards } from '@nestjs/common';
import { OptionalJwtUserGuard } from '../auth/optional-jwt-user.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { UsersService } from './users.service';

@Controller('v1/users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get(':userId/public-profile')
  @Header('Content-Type', 'application/json')
  @UseGuards(OptionalJwtUserGuard)
  async getPublicProfile(
    @Param('userId') userId: string,
    @Req() req?: { user?: JwtValidatedUser },
  ) {
    return await this.users.getPublicCreatorProfile({
      targetUserId: userId,
      viewerUserId: req?.user?.userId ?? null,
    });
  }
}

