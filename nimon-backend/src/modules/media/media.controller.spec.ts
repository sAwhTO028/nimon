import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  Injectable,
  UnauthorizedException,
  type CanActivate,
  type ExecutionContext,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test, type TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { DiskMediaStorage } from './disk-media.storage';
import { MEDIA_STORAGE } from './media-storage';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

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
    req.user = {
      userId: '33333333-3333-3333-3333-333333333333',
      email: null,
    };
    return true;
  }
}

describe('MediaController (upload)', () => {
  let app: TestingModule;
  let uploadRoot: string;

  beforeAll(() => {
    uploadRoot = mkdtempSync(join(tmpdir(), 'nimon-media-'));
    process.env.MEDIA_UPLOAD_DIR = uploadRoot;
    process.env.MEDIA_PUBLIC_BASE_URL = 'http://localhost:3000/uploads';
    process.env.MEDIA_COVER_MAX_BYTES = '10485760';
    process.env.MEDIA_AUDIO_MAX_BYTES = '52428800';
  });

  afterAll(() => {
    if (uploadRoot) {
      rmSync(uploadRoot, { recursive: true, force: true });
    }
  });

  beforeEach(async () => {
    app = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
        }),
      ],
      controllers: [MediaController],
      providers: [
        DiskMediaStorage,
        {
          provide: MEDIA_STORAGE,
          useExisting: DiskMediaStorage,
        },
        MediaService,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useClass(TestJwtGuard)
      .compile();
  });

  it('rejects unauthenticated upload (no Bearer)', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .expect(401);
    expect(res.status).toBe(401);
    await nest.close();
  });

  it('rejects missing file', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .expect(400);
    expect(res.body.message).toContain('file');
    await nest.close();
  });

  it('rejects invalid cover mime', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .attach('file', Buffer.from('%PDF'), {
        filename: 'x.pdf',
        contentType: 'application/pdf',
      })
      .expect(415);
    expect(res.status).toBe(415);
    await nest.close();
  });

  it('cover upload accepts image/jpg and returns image/jpeg', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const buf = Buffer.alloc(8, 1);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .attach('file', buf, {
        filename: 'cover.jpg',
        contentType: 'image/jpg',
      })
      .expect(201);
    expect(res.body.mediaType).toBe('image/jpeg');
    await nest.close();
  });

  it('cover upload accepts application/octet-stream with .jpg filename', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const buf = Buffer.alloc(4, 2);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .attach('file', buf, {
        filename: 'photo.jpg',
        contentType: 'application/octet-stream',
      })
      .expect(201);
    expect(res.body.mediaType).toBe('image/jpeg');
    await nest.close();
  });

  it('cover upload rejects application/octet-stream with .pdf filename', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .attach('file', Buffer.from('%PDF'), {
        filename: 'photo.pdf',
        contentType: 'application/octet-stream',
      })
      .expect(415);
    expect(res.status).toBe(415);
    await nest.close();
  });

  it('cover upload returns url, mediaType, originalName, sizeBytes', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const png = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/cover')
      .set('Authorization', 'Bearer test-token')
      .attach('file', png, { filename: 'cover.png', contentType: 'image/png' })
      .expect(201);
    expect(res.body.url).toMatch(/^http:\/\/localhost:3000\/uploads\//);
    expect(res.body.mediaType).toBe('image/png');
    expect(res.body.originalName).toBe('cover.png');
    expect(res.body.sizeBytes).toBe(png.length);
    expect(res.body.durationSeconds).toBeNull();
    await nest.close();
  });

  it('audio upload returns url, mediaType, originalName, sizeBytes', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const buf = Buffer.alloc(64, 1);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/audio')
      .set('Authorization', 'Bearer test-token')
      .attach('file', buf, {
        filename: 'story.mp3',
        contentType: 'audio/mpeg',
      })
      .expect(201);
    expect(res.body.url).toContain('/audio/');
    expect(res.body.mediaType).toBe('audio/mpeg');
    expect(res.body.originalName).toBe('story.mp3');
    expect(res.body.sizeBytes).toBe(64);
    expect(res.body.durationSeconds).toBeNull();
    await nest.close();
  });

  it('audio upload accepts application/octet-stream with .mp3 filename', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const buf = Buffer.alloc(32, 2);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/audio')
      .set('Authorization', 'Bearer test-token')
      .attach('file', buf, {
        filename: 'song.mp3',
        contentType: 'application/octet-stream',
      })
      .expect(201);
    expect(res.body.mediaType).toBe('audio/mpeg');
    await nest.close();
  });

  it('audio upload accepts application/octet-stream with .m4a filename', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const buf = Buffer.alloc(16, 3);
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/audio')
      .set('Authorization', 'Bearer test-token')
      .attach('file', buf, {
        filename: 'song.m4a',
        contentType: 'application/octet-stream',
      })
      .expect(201);
    expect(res.body.mediaType).toBe('audio/mp4');
    await nest.close();
  });

  it('audio upload rejects application/octet-stream with .pdf filename', async () => {
    const nest = app.createNestApplication();
    await nest.init();
    const res = await request(nest.getHttpServer())
      .post('/v1/media/upload/audio')
      .set('Authorization', 'Bearer test-token')
      .attach('file', Buffer.from('%PDF'), {
        filename: 'document.pdf',
        contentType: 'application/octet-stream',
      })
      .expect(415);
    expect(res.status).toBe(415);
    await nest.close();
  });
});
