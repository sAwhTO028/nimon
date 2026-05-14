import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule, type JwtModuleOptions } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { MediaUrlCanonicalizerModule } from '../media/media-url-canonicalizer.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { JwtOrDevOwnerFallbackGuard } from './jwt-or-dev-owner-fallback.guard';
import { JwtStrategy } from './jwt.strategy';
import { MeController } from './me.controller';
import { OptionalJwtUserGuard } from './optional-jwt-user.guard';
import {
  resolveAccessExpiresIn,
  resolveJwtSecret,
} from './auth.config';

@Module({
  imports: [
    MediaUrlCanonicalizerModule,
    PrismaModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService): JwtModuleOptions => ({
        secret: resolveJwtSecret(config),
        signOptions: {
          // Runtime matches JwtModule / env (`15m`, etc.). Narrow union avoided — no direct jsonwebtoken import.
          expiresIn: resolveAccessExpiresIn(config) as never,
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController, MeController],
  providers: [
    AuthService,
    JwtStrategy,
    JwtAuthGuard,
    JwtOrDevOwnerFallbackGuard,
    OptionalJwtUserGuard,
  ],
  exports: [
    AuthService,
    JwtModule,
    JwtAuthGuard,
    JwtOrDevOwnerFallbackGuard,
    OptionalJwtUserGuard,
  ],
})
export class AuthModule {}
