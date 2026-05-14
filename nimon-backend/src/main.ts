import { isAbsolute, resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';
import * as express from 'express';
import type { NextFunction, Request, Response } from 'express';
import {
  applyUploadsStaticCors,
  isLocalWebDevOrigin,
} from './common/uploads-static-cors';

const corsOptions: CorsOptions = {
  origin: (reqOrigin, callback) => {
    const configured = process.env.CORS_ORIGIN?.trim();
    if (configured === '*') {
      // Reflect request Origin (works with credentials: true; unlike literal `*`).
      callback(null, true);
      return;
    }
    if (configured && configured !== '*' && reqOrigin === configured) {
      callback(null, true);
      return;
    }
    if (isLocalWebDevOrigin(reqOrigin)) {
      // `true` = reflect request Origin in Access-Control-Allow-Origin (required with credentials: true; cannot be *).
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'If-Match',
    'Authorization',
    'Accept',
    'X-Requested-With',
  ],
  exposedHeaders: ['ETag'],
  credentials: true,
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

/** Align with {@link MediaService} upload root resolution for static `/uploads`. */
function resolveUploadRootAbs(): string {
  const fallback = 'uploads';
  const raw = process.env.MEDIA_UPLOAD_DIR?.trim();
  if (!raw) {
    return resolve(process.cwd(), fallback);
  }
  const trimmed = raw.replace(/^[/\\]+/, '').trim() || fallback;
  if (trimmed.includes('..')) {
    return resolve(process.cwd(), fallback);
  }
  if (isAbsolute(trimmed)) {
    return trimmed;
  }
  return resolve(process.cwd(), trimmed);
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const uploadAbs = resolveUploadRootAbs();
  app.use(
    '/uploads',
    (req: Request, res: Response, next: NextFunction) => {
      applyUploadsStaticCors(req, res);
      if (req.method === 'OPTIONS') {
        res.status(204).end();
        return;
      }
      next();
    },
    express.static(uploadAbs),
  );
  app.enableCors(corsOptions);
  app.enableShutdownHooks();
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }),
  );
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  // M17C-5 TEMP: prove which Node process / build is actually listening (remove after diagnosis).
  console.log(
    `[M17C-5] nimon-backend bootstrap ok startedAt=${new Date().toISOString()} port=${port} pid=${process.pid} node=${process.version}`,
  );
}
bootstrap();
