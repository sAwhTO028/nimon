import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import type { JwtValidatedUser } from './jwt.strategy';
import { PatchMeProfileDto } from './dto/me-profile.dto';

@Controller('v1')
export class MeController {
  constructor(private readonly auth: AuthService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: { user: JwtValidatedUser }) {
    return this.auth.getMe(req.user.userId);
  }

  @Get('me/profile')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  meProfile(@Req() req: { user: JwtValidatedUser }) {
    return this.auth.getMeProfile(req.user.userId);
  }

  @Patch('me/profile')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'application/json')
  patchMeProfile(
    @Req() req: { user: JwtValidatedUser },
    @Body() body: PatchMeProfileDto,
  ) {
    return this.auth.patchMeProfile(req.user.userId, body);
  }
}
