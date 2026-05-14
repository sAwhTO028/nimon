import {
  BadRequestException,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'node:crypto';
import { canonicalizeMediaUrl } from '../media/media-url-canonicalizer';
import type { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

/** Matches `AuthService` private hashing for test fixtures. */
function hashRefreshOpaque(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function mkMedia(): MediaUrlCanonicalizerService {
  const base = 'http://localhost:3000/uploads';
  return {
    mediaPublicBaseUrl: () => base,
    url: (u: string | null | undefined) => canonicalizeMediaUrl(u, base),
  } as unknown as MediaUrlCanonicalizerService;
}

describe('AuthService', () => {
  let service: AuthService;
  let prisma: jest.Mocked<
    Pick<PrismaService, '$transaction' | 'user' | 'refreshToken'>
  >;
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
        update: jest.fn(),
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
      mkMedia(),
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

    it('rejects structurally invalid email with validation_failed', async () => {
      try {
        await service.register({ email: 'not-an-email', password: 'secretpass' });
        throw new Error('expected BadRequestException');
      } catch (e) {
        expect(e).toBeInstanceOf(BadRequestException);
        const body = (e as BadRequestException).getResponse() as Record<
          string,
          unknown
        >;
        expect(body['message']).toBe('validation_failed');
        const issues = body['issues'] as Array<{ field?: string }>;
        expect(issues.some((i) => i.field === 'email')).toBe(true);
      }
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
    const validPlain = 'valid-refresh-plain-token-xxxxxxxx';
    const validHash = hashRefreshOpaque(validPlain);
    const future = new Date(Date.now() + 3_600_000);

    it('rejects unknown refresh token', async () => {
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue(null);

      await expect(service.refresh('bogus-token')).rejects.toThrow(
        'Invalid refresh token',
      );
    });

    it('rotates: returns new access + new refresh and revokes old row in transaction', async () => {
      const row = {
        userId: '22222222-2222-2222-2222-222222222222',
        tokenHash: validHash,
        revokedAt: null,
        expiresAt: future,
      };
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue(row);
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '22222222-2222-2222-2222-222222222222',
        email: 'u@example.com',
      });

      const txUpdate = jest.fn().mockResolvedValue({});
      const txCreate = jest.fn().mockResolvedValue({});
      prisma.$transaction = jest.fn(async (fn: any) => {
        return fn({
          refreshToken: {
            findUnique: jest.fn().mockResolvedValue(row),
            update: txUpdate,
            create: txCreate,
          },
        });
      });

      const out = await service.refresh(validPlain);

      expect(out.accessToken).toBe('signed-access-token');
      expect(out.tokenType).toBe('Bearer');
      expect(out.refreshToken).not.toBe(validPlain);
      expect(out.refreshToken.length).toBeGreaterThan(20);
      expect(txUpdate).toHaveBeenCalledWith({
        where: { tokenHash: validHash },
        data: { revokedAt: expect.any(Date) },
      });
      const createArg = txCreate.mock.calls[0][0] as {
        data: { tokenHash: string; userId: string; expiresAt: Date };
      };
      expect(createArg.data.userId).toBe('22222222-2222-2222-2222-222222222222');
      expect(createArg.data.tokenHash).toBe(hashRefreshOpaque(out.refreshToken));
      expect(createArg.data.expiresAt).toBeInstanceOf(Date);
    });

    it('rejects expired refresh without revoking other sessions', async () => {
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue({
        userId: '22222222-2222-2222-2222-222222222222',
        tokenHash: validHash,
        revokedAt: null,
        expiresAt: new Date(Date.now() - 1000),
      });
      prisma.refreshToken.updateMany = jest.fn();

      await expect(service.refresh(validPlain)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(prisma.refreshToken.updateMany).not.toHaveBeenCalled();
    });

    it('reuse: revoked token revokes all active refresh rows for user then rejects', async () => {
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue({
        userId: '22222222-2222-2222-2222-222222222222',
        tokenHash: validHash,
        revokedAt: new Date('2026-01-01T00:00:00.000Z'),
        expiresAt: future,
      });
      prisma.refreshToken.updateMany = jest.fn().mockResolvedValue({ count: 2 });

      await expect(service.refresh(validPlain)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: {
          userId: '22222222-2222-2222-2222-222222222222',
          revokedAt: null,
          expiresAt: { gt: expect.any(Date) },
        },
        data: { revokedAt: expect.any(Date) },
      });
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('rejects when transaction sees row already revoked (race)', async () => {
      const row = {
        userId: '22222222-2222-2222-2222-222222222222',
        tokenHash: validHash,
        revokedAt: null,
        expiresAt: future,
      };
      prisma.refreshToken.findUnique = jest.fn().mockResolvedValue(row);
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: '22222222-2222-2222-2222-222222222222',
        email: 'u@example.com',
      });
      prisma.$transaction = jest.fn(async (fn: any) => {
        return fn({
          refreshToken: {
            findUnique: jest.fn().mockResolvedValue({
              ...row,
              revokedAt: new Date(),
            }),
            update: jest.fn(),
            create: jest.fn(),
          },
        });
      });

      await expect(service.refresh(validPlain)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('logout', () => {
    it('revokes refresh token row when still active', async () => {
      prisma.refreshToken.updateMany = jest.fn().mockResolvedValue({ count: 1 });
      await service.logout('some-refresh-token-plain');
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: {
          tokenHash: hashRefreshOpaque('some-refresh-token-plain'),
          revokedAt: null,
        },
        data: { revokedAt: expect.any(Date) },
      });
    });

    it('is idempotent when token unknown or already revoked', async () => {
      prisma.refreshToken.updateMany = jest.fn().mockResolvedValue({ count: 0 });
      await expect(service.logout('unknown')).resolves.toBeUndefined();
      await expect(service.logout('unknown')).resolves.toBeUndefined();
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledTimes(2);
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

  describe('patchMeProfile', () => {
    it('rejects invalid handle with validation_failed on handle field', async () => {
      prisma.user.findUnique = jest.fn().mockResolvedValue({
        id: 'u1',
        email: 'a@b.com',
      });

      try {
        await service.patchMeProfile('u1', { handle: 'ab' } as any);
        throw new Error('expected BadRequestException');
      } catch (e) {
        expect(e).toBeInstanceOf(BadRequestException);
        const body = (e as BadRequestException).getResponse() as Record<
          string,
          unknown
        >;
        expect(body['message']).toBe('validation_failed');
        const issues = body['issues'] as Array<{ field?: string }>;
        expect(issues.some((i) => i.field === 'handle')).toBe(true);
      }
    });
  });
});
