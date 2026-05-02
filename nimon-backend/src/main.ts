import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

/**
 * True when the request Origin is safe for local Flutter Web / Vite / webpack-dev-server.
 * (CORS does not support `http://localhost:*` as a string; we validate the URL instead.)
 */
function isLocalWebDevOrigin(origin: string | undefined): boolean {
  if (origin == null || origin.length === 0) {
    // e.g. Postman, curl, same-origin, or some embedded contexts
    return true;
  }
  try {
    const u = new URL(origin);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') {
      return false;
    }
    const h = u.hostname;
    if (h === 'localhost' || h === '127.0.0.1' || h === '::1' || h === '[::1]') {
      return true;
    }
  } catch {
    return false;
  }
  return false;
}

const corsOptions: CorsOptions = {
  origin: (reqOrigin, callback) => {
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

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors(corsOptions);
  app.enableShutdownHooks();
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }),
  );
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
