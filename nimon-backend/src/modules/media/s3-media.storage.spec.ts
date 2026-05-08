import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { ConfigService } from '@nestjs/config';
import { S3MediaStorage } from './s3-media.storage';

describe('S3MediaStorage', () => {
  const userId = '11111111-1111-1111-1111-111111111111';

  it('sends PutObjectCommand with Bucket, Key, ContentType, Body, ContentLength', async () => {
    const send = jest.fn().mockResolvedValue({});
    const client = { send } as unknown as S3Client;

    const config = new ConfigService({
      MEDIA_BUCKET: 'my-bucket',
      MEDIA_REGION: 'auto',
      MEDIA_ACCESS_KEY_ID: 'x',
      MEDIA_SECRET_ACCESS_KEY: 'y',
      MEDIA_PUBLIC_BASE_URL: 'https://assets.example.com',
    });

    const storage = new S3MediaStorage(config, { client });

    await storage.save({
      userId,
      kind: 'cover',
      buffer: Buffer.from('hello'),
      extension: '.png',
      mediaType: 'image/png',
    });

    expect(send).toHaveBeenCalledTimes(1);
    const cmd = send.mock.calls[0][0] as PutObjectCommand;
    expect(cmd).toBeInstanceOf(PutObjectCommand);
    expect(cmd.input).toEqual(
      expect.objectContaining({
        Bucket: 'my-bucket',
        Key: expect.stringMatching(
          new RegExp(
            `^${userId}/cover/[0-9]+-[a-f0-9-]+\\.png$`,
          ),
        ),
        Body: Buffer.from('hello'),
        ContentType: 'image/png',
        ContentLength: 5,
      }),
    );
  });

  it('returns url from MEDIA_PUBLIC_BASE_URL with encoded path segments', async () => {
    const send = jest.fn().mockResolvedValue({});
    const client = { send } as unknown as S3Client;

    const config = new ConfigService({
      MEDIA_BUCKET: 'b',
      MEDIA_REGION: 'eu-west-1',
      MEDIA_ACCESS_KEY_ID: 'a',
      MEDIA_SECRET_ACCESS_KEY: 's',
      MEDIA_PUBLIC_BASE_URL: 'https://cdn.test/',
      MEDIA_OBJECT_KEY_PREFIX: 'v1//',
    });

    const storage = new S3MediaStorage(config, { client });

    const out = await storage.save({
      userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      kind: 'audio',
      buffer: Buffer.alloc(1),
      extension: '.mp3',
      mediaType: 'audio/mpeg',
    });

    expect(out.key).toMatch(/^v1\/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\/audio\//);
    const keySegments = out.key.split('/');
    const encoded = keySegments.map((s) => encodeURIComponent(s)).join('/');
    expect(out.url).toBe(`https://cdn.test/${encoded}`);
  });
});
