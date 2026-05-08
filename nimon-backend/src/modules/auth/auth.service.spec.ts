import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: jest.Mocked<Pick<PrismaService, '$transaction' | 'user' | 'refreshToken'>>;
  let jwt: jest.Mocked<Pick<JwtService, 'signAsync'>>;
  let config: ConfigService;

  beforeEach(() => {
    prisma = {
      $transaction: jest.fn(),
      user: {
        findUnique: jest.fn(),
        create: jest.fn(),
      } as any,
      refreshToken: {
        create: jest.fn(),
        findUnique: jest.fn(),
        updateMany: jest.fn(),
      } as any,
    } as any;

    jwt = {
      signAsync: jest.fn().mockResolvedValue('signed-access-token'),
    };

    config = new ConfigService({
      JWT_REFRESH_EXPIRES_IN: '3600',
    });

    service = new AuthService(
      prisma as unknown as PrismaService,
      jwt as unknown as JwtService,
      config,
    );
  });

  describe('register', () => {
    it('creates user with bcrypt passwordHash (not plaintext)', async () => {
      prisma.user.findUnique = jest.fn().mockResolvedValue(null);

      let createdPasswordHash: string | undefined;
      const fakeTx = {
        user: {
          create: jest.fn().mockImplementation(({ data }: any) => {
            createdPasswordHash = data.passwordHash;
            return Promise.resolve({
              id: '11111111-1111-1111-1111-111111111111',
              email: data.email,
              passwordHash: data.passwordHash,
            });
          }),
        },
        userProfile: {
          create: jest.fn().mockResolvedValue({}),
        },
        refreshToken: {
          create: jest.fn().mockResolvedValue({}),
        },
      } as const;

      prisma.$transaction = jest.fn(async (fn: any) => fn(fakeTx));

      const out = await service.register({
        email: 'new@example.com',
        password: 'secretpass',
      });

      expect(createdPasswordHash).toBeDefined();
      expect(createdPasswordHash).not.toBe('secretpass');
      expect(createdPasswordHash).toMatch(/^\$2[aby]\$/);
      expect(out.accessToken).toBe('signed-access-token');
      expect(out.refreshToken.length).toBeGreaterThan(20);
      expect(out.tokenType).toBe('Bearer');
      expect(jwt.signAsync).toHaveBeenCalledWith(
        expect.objectContaining({
          sub: '11111111-1111-1111-1111-111111111111',
          email: 'new@example.com',
        }),
      );
    });

    it('rejects duplicate email', async () => {
      prisma.user.findUnique = jest
        .fn()
        .mockResolvedValue({ id: 'x', email: 'dup@example.com' });

      await expect(
        service.register({ email: 'dup@example.com', password: 'secretpass' }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('returns accessToken on valid password', async () => {
      const hash = bcrypt.hashSync('right-password', 4);
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '22222222-2222-2222-2222-222222222222',
        email: 'u@example.com',
        passwordHash: hash,
      });
      prisma.refreshToken.updateMany = jest.fn().mockResolvedValue({ count: 0 });
      prisma.refreshToken.create = jest.fn().mockResolvedValue({});

      const out = await service.login({
        email: 'u@example.com',
        password: 'right-password',
      });

      expect(out.accessToken).toBe('signed-access-token');
      expect(out.refreshToken.length).toBeGreaterThan(20);
      expect(jwt.signAsync).toHaveBeenCalledWith(
        expect.objectContaining({
          sub: '22222222-2222-2222-2222-222222222222',
          email: 'u@example.com',
        }),
      );
    });

    it('rejects wrong password', async () => {
      const hash = bcrypt.hashSync('right-password', 4);
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '22222222-2222-2222-2222-222222222222',
        email: 'u@example.com',
        passwordHash: hash,
      });

      await expect(
        service.login({
          email: 'u@example.com',
          password: 'wrong-password',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects user without passwordHash', async () => {
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '22222222-2222-2222-2222-222222222222',
        email: 'u@example.com',
        passwordHash: null,
      });

      await expect(
        service.login({
          email: 'u@example.com',
          password: 'any',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });

  describe('refresh', () => {
    it('rejects unknown refresh token', async () => {
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue(null);

      await expect(service.refresh('bogus-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('getMe', () => {
    it('returns user and profile', async () => {
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '33333333-3333-3333-3333-333333333333',
        email: 'me@example.com',
        profile: {
          displayName: 'Me',
          handle: null,
          avatarUrl: null,
          bio: null,
          createdAt: new Date('2026-01-01T00:00:00.000Z'),
          updatedAt: new Date('2026-01-02T00:00:00.000Z'),
        },
      });

      const me = await service.getMe('33333333-3333-3333-3333-333333333333');
      expect(me.user.id).toBe('33333333-3333-3333-3333-333333333333');
      expect(me.user.email).toBe('me@example.com');
      expect(me.profile?.displayName).toBe('Me');
    });
  });
});
