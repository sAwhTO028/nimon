import {
  Injectable,
  UnauthorizedException,
  type CanActivate,
  type ExecutionContext,
} from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test, type TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { ValidationPipe } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import type { JwtValidatedUser } from './jwt.strategy';
import { MeController } from './me.controller';

@Injectable()
class TestJwtGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context
      .switchToHttp()
      .getRequest<{ headers?: { authorization?: string }; user?: JwtValidatedUser }>();
    const auth = req.headers?.authorization;
    if (!auth?.startsWith('Bearer ')) {
      throw new UnauthorizedException();
    }
    req.user = { userId: 'u1', email: 'me@example.com' };
    return true;
  }
}

describe('MeController profile', () => {
  let app: TestingModule;

  beforeEach(async () => {
    const prisma = {
      user: {
        findUnique: jest.fn(),
      },
      userProfile: {
        upsert: jest.fn(),
      },
    };

    app = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
        }),
      ],
      controllers: [MeController],
      providers: [
        { provide: 'PRISMA', useValue: prisma },
        {
          provide: AuthService,
          useFactory: (config: ConfigService) =>
            new AuthService(prisma as any, new JwtService({} as any), config),
          inject: [ConfigService],
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useClass(TestJwtGuard)
      .compile();
  });

  it('GET /v1/me/profile requires auth', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer()).get('/v1/me/profile').expect(401);
    await nest.close();
  });

  it('GET /v1/me/profile returns email + profile fields', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'me@example.com',
      profile: {
        displayName: 'Me',
        handle: 'me',
        avatarUrl: 'https://img.test/a.png',
        coverImageUrl: 'https://img.test/c.png',
        bio: 'b',
      },
    });

    const res = await request(nest.getHttpServer())
      .get('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .expect(200);

    expect(res.body.user.email).toBe('me@example.com');
    expect(res.body.profile.coverImageUrl).toBe('https://img.test/c.png');
    await nest.close();
  });

  it('PATCH /v1/me/profile trims and normalizes handle', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'me@example.com' });
    prisma.userProfile.upsert.mockResolvedValue({
      displayName: null,
      handle: 'name_1',
      avatarUrl: null,
      coverImageUrl: null,
      bio: null,
    });

    const res = await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ handle: ' @Name_1 ' })
      .expect(200);

    expect(prisma.userProfile.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ handle: 'name_1' }),
        update: expect.objectContaining({ handle: 'name_1' }),
      }),
    );
    expect(res.body.profile.handle).toBe('name_1');
    await nest.close();
  });

  it('PATCH rejects invalid handle', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ handle: 'bad!!' })
      .expect(400);
    await nest.close();
  });

  it('PATCH rejects invalid avatarUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ avatarUrl: 'ftp://x' })
      .expect(400);
    await nest.close();
  });

  it('PATCH accepts localhost http avatarUrl and coverImageUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'me@example.com' });
    prisma.userProfile.upsert.mockResolvedValue({
      displayName: null,
      handle: null,
      avatarUrl: 'http://localhost:3000/uploads/avatar.jpg',
      coverImageUrl: 'http://localhost:3000/uploads/cover.jpg',
      bio: null,
    });

    const res = await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({
        avatarUrl: 'http://localhost:3000/uploads/avatar.jpg',
        coverImageUrl: 'http://localhost:3000/uploads/cover.jpg',
      })
      .expect(200);

    expect(res.body.profile.avatarUrl).toBe('http://localhost:3000/uploads/avatar.jpg');
    expect(res.body.profile.coverImageUrl).toBe('http://localhost:3000/uploads/cover.jpg');
    await nest.close();
  });

  it('PATCH accepts 127.0.0.1 http avatarUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'me@example.com' });
    prisma.userProfile.upsert.mockResolvedValue({
      displayName: null,
      handle: null,
      avatarUrl: 'http://127.0.0.1:3000/uploads/a.jpg',
      coverImageUrl: null,
      bio: null,
    });

    const res = await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ avatarUrl: 'http://127.0.0.1:3000/uploads/a.jpg' })
      .expect(200);

    expect(res.body.profile.avatarUrl).toBe('http://127.0.0.1:3000/uploads/a.jpg');
    await nest.close();
  });

  it('PATCH accepts https CDN avatarUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'me@example.com' });
    prisma.userProfile.upsert.mockResolvedValue({
      displayName: null,
      handle: null,
      avatarUrl: 'https://cdn.example.com/avatar.jpg',
      coverImageUrl: null,
      bio: null,
    });

    const res = await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ avatarUrl: 'https://cdn.example.com/avatar.jpg' })
      .expect(200);

    expect(res.body.profile.avatarUrl).toBe('https://cdn.example.com/avatar.jpg');
    await nest.close();
  });

  it('PATCH rejects file:// avatarUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ avatarUrl: 'file:///tmp/a.jpg' })
      .expect(400);
    await nest.close();
  });

  it('PATCH rejects javascript: avatarUrl', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ avatarUrl: 'javascript:alert(1)' })
      .expect(400);
    await nest.close();
  });

  it('PATCH rejects non-whitelisted email field', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();
    await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ email: 'x@example.com' })
      .expect(400);
    await nest.close();
  });

  it('PATCH returns 409 handle_taken on duplicate handle', async () => {
    const nest = app.createNestApplication();
    nest.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
    );
    await nest.init();

    const prisma = nest.get('PRISMA') as any;
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'me@example.com' });
    prisma.userProfile.upsert.mockImplementation(() => {
      // Simulate Prisma unique constraint violation on handle.
      throw new Prisma.PrismaClientKnownRequestError('Unique', {
        code: 'P2002',
        clientVersion: 'test',
        meta: { target: ['handle'] },
      } as any);
    });

    const res = await request(nest.getHttpServer())
      .patch('/v1/me/profile')
      .set('Authorization', 'Bearer t')
      .send({ handle: 'taken_1' })
      .expect(409);

    expect(res.body.message?.code ?? res.body.code).toBe('handle_taken');
    await nest.close();
  });
});

