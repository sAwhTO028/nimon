import {
  DEFAULT_NIMON_PUBLIC_WEB_BASE_URL,
  monShareUrlForMonoId,
  normalizeNimonPublicWebBaseUrl,
} from './nimon-public-web-url';

describe('normalizeNimonPublicWebBaseUrl', () => {
  it('uses default when empty', () => {
    expect(normalizeNimonPublicWebBaseUrl(null)).toBe(
      DEFAULT_NIMON_PUBLIC_WEB_BASE_URL,
    );
    expect(normalizeNimonPublicWebBaseUrl('')).toBe(
      DEFAULT_NIMON_PUBLIC_WEB_BASE_URL,
    );
    expect(normalizeNimonPublicWebBaseUrl('   ')).toBe(
      DEFAULT_NIMON_PUBLIC_WEB_BASE_URL,
    );
  });

  it('trims and removes trailing slashes', () => {
    expect(
      normalizeNimonPublicWebBaseUrl('http://192.168.11.5:3000///'),
    ).toBe('http://192.168.11.5:3000');
  });

  it('accepts production host', () => {
    expect(normalizeNimonPublicWebBaseUrl('https://nimon.app')).toBe(
      'https://nimon.app',
    );
  });
});

describe('monShareUrlForMonoId', () => {
  it('builds path under base', () => {
    expect(monShareUrlForMonoId('http://192.168.11.5:3000', 'abc')).toBe(
      'http://192.168.11.5:3000/mono/abc',
    );
  });

  it('no double slash when base has trailing slash (normalized)', () => {
    expect(monShareUrlForMonoId('http://192.168.11.5:3000/', 'x')).toBe(
      'http://192.168.11.5:3000/mono/x',
    );
  });
});
