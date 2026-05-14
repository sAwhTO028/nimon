import {
  canonicalizeMediaUrl,
  clonePublishedContentWithCanonicalMedia,
  normalizeMediaPublicBaseUrl,
} from './media-url-canonicalizer';

describe('canonicalizeMediaUrl', () => {
  const base = 'http://192.168.11.5:3000/uploads';

  it('returns null for null, undefined, empty, whitespace-only', () => {
    expect(canonicalizeMediaUrl(null, base)).toBeNull();
    expect(canonicalizeMediaUrl(undefined, base)).toBeNull();
    expect(canonicalizeMediaUrl('', base)).toBeNull();
    expect(canonicalizeMediaUrl('   ', base)).toBeNull();
  });

  it('rewrites path-only /uploads/... URLs', () => {
    expect(canonicalizeMediaUrl('/uploads/u/cover/a.jpg', base)).toBe(
      'http://192.168.11.5:3000/uploads/u/cover/a.jpg',
    );
  });

  it('rewrites localhost /uploads URLs', () => {
    expect(
      canonicalizeMediaUrl(
        'http://localhost:3000/uploads/u/cover/a.webp',
        base,
      ),
    ).toBe('http://192.168.11.5:3000/uploads/u/cover/a.webp');
  });

  it('rewrites 127.0.0.1 /uploads URLs', () => {
    expect(
      canonicalizeMediaUrl(
        'http://127.0.0.1:3000/uploads/u/cover/a.webp',
        base,
      ),
    ).toBe('http://192.168.11.5:3000/uploads/u/cover/a.webp');
  });

  it('rewrites [::1] IPv6 loopback /uploads URLs', () => {
    expect(
      canonicalizeMediaUrl(
        'http://[::1]:3000/uploads/u/cover/a.webp',
        base,
      ),
    ).toBe('http://192.168.11.5:3000/uploads/u/cover/a.webp');
  });

  it('leaves current LAN upload URL unchanged', () => {
    const u = 'http://192.168.11.5:3000/uploads/u/cover/a.jpg';
    expect(canonicalizeMediaUrl(u, base)).toBe(u);
  });

  it('leaves external https CDN URLs unchanged', () => {
    expect(
      canonicalizeMediaUrl('https://cdn.example.com/uploads/u/cover/a.jpg', base),
    ).toBe('https://cdn.example.com/uploads/u/cover/a.jpg');
    expect(canonicalizeMediaUrl('https://example.com/image.jpg', base)).toBe(
      'https://example.com/image.jpg',
    );
  });

  it('preserves query strings on loopback uploads URLs', () => {
    expect(
      canonicalizeMediaUrl(
        'http://localhost:3000/uploads/u/c/a.webp?v=1',
        base,
      ),
    ).toBe('http://192.168.11.5:3000/uploads/u/c/a.webp?v=1');
  });

  it('returns original string for malformed non-upload input', () => {
    expect(canonicalizeMediaUrl('not a url', base)).toBe('not a url');
  });

  it('does not rewrite localhost non-upload paths', () => {
    const u = 'http://localhost:3000/mono/abc';
    expect(canonicalizeMediaUrl(u, base)).toBe(u);
  });
});

describe('normalizeMediaPublicBaseUrl', () => {
  it('trims trailing slashes', () => {
    expect(normalizeMediaPublicBaseUrl('http://x/uploads///')).toBe(
      'http://x/uploads',
    );
  });
});

describe('clonePublishedContentWithCanonicalMedia', () => {
  const base = 'http://192.168.11.5:3000/uploads';

  it('canonicalizes nested core.coverImageUrl and learn.audio.storyAudio.sourceUrl', () => {
    const raw = {
      core: {
        coverImageUrl: 'http://localhost:3000/uploads/a/b.webp',
      },
      learn: {
        audio: {
          storyAudio: {
            sourceUrl: 'http://127.0.0.1:3000/uploads/a/story.mp3',
          },
        },
      },
    };
    const out = clonePublishedContentWithCanonicalMedia(raw, base) as any;
    expect(out).not.toBe(raw);
    expect(out.core.coverImageUrl).toBe(
      'http://192.168.11.5:3000/uploads/a/b.webp',
    );
    expect(out.learn.audio.storyAudio.sourceUrl).toBe(
      'http://192.168.11.5:3000/uploads/a/story.mp3',
    );
  });

  it('leaves external audio URLs unchanged', () => {
    const raw = {
      learn: {
        audio: {
          storyAudio: {
            sourceUrl: 'https://cdn.example.com/a.mp3',
          },
        },
      },
    };
    const out = clonePublishedContentWithCanonicalMedia(raw, base) as any;
    expect(out.learn.audio.storyAudio.sourceUrl).toBe(
      'https://cdn.example.com/a.mp3',
    );
  });
});
