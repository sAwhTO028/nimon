import type { IncomingMessage } from 'node:http';
import {
  resolveUploadsAccessControlAllowOrigin,
  isLocalWebDevOrigin,
} from './uploads-static-cors';

function mockReq(origin: string | undefined): Pick<IncomingMessage, 'headers'> {
  return {
    headers: origin === undefined ? {} : { origin },
  };
}

describe('uploads-static-cors', () => {
  const origEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...origEnv };
    delete process.env.CORS_ORIGIN;
    delete process.env.NODE_ENV;
  });

  afterAll(() => {
    process.env = origEnv;
  });

  describe('isLocalWebDevOrigin', () => {
    it('treats missing origin as allowed context', () => {
      expect(isLocalWebDevOrigin(undefined)).toBe(true);
    });

    it('allows localhost http origins', () => {
      expect(isLocalWebDevOrigin('http://localhost:8080')).toBe(true);
    });
  });

  describe('resolveUploadsAccessControlAllowOrigin', () => {
    it('returns * when CORS_ORIGIN is *', () => {
      process.env.CORS_ORIGIN = '*';
      expect(resolveUploadsAccessControlAllowOrigin(mockReq('http://evil.test'))).toBe(
        '*',
      );
    });

    it('returns configured origin string when set', () => {
      process.env.CORS_ORIGIN = 'https://app.example.com';
      expect(
        resolveUploadsAccessControlAllowOrigin(mockReq('https://app.example.com')),
      ).toBe('https://app.example.com');
    });

    it('reflects localhost Origin when CORS_ORIGIN unset (non-production)', () => {
      process.env.NODE_ENV = 'development';
      expect(
        resolveUploadsAccessControlAllowOrigin(
          mockReq('http://localhost:12345'),
        ),
      ).toBe('http://localhost:12345');
    });

    it('falls back to * in non-production when Origin unset', () => {
      process.env.NODE_ENV = 'development';
      expect(resolveUploadsAccessControlAllowOrigin(mockReq(undefined))).toBe('*');
    });

    it('returns null in production when CORS_ORIGIN unset and Origin not local', () => {
      process.env.NODE_ENV = 'production';
      expect(
        resolveUploadsAccessControlAllowOrigin(mockReq('https://other.example')),
      ).toBeNull();
    });
  });
});
