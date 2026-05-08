import { mkdir, writeFile } from 'node:fs/promises';
import { ConfigService } from '@nestjs/config';
import { DiskMediaStorage } from './disk-media.storage';

jest.mock('node:fs/promises', () => ({
  mkdir: jest.fn(),
  writeFile: jest.fn(),
}));

const mockedMkdir = mkdir as jest.MockedFunction<typeof mkdir>;
const mockedWriteFile = writeFile as jest.MockedFunction<typeof writeFile>;

describe('DiskMediaStorage', () => {
  const userId = '11111111-1111-1111-1111-111111111111';

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.MEDIA_PUBLIC_BASE_URL = 'http://localhost:3000/uploads';
    process.env.MEDIA_UPLOAD_DIR = 'uploads';
    mockedMkdir.mockResolvedValue(undefined);
    mockedWriteFile.mockResolvedValue(undefined);
  });

  it('writes under uploadRoot/userId/kind and returns encoded url', async () => {
    const config = new ConfigService({
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:3000/uploads',
      MEDIA_UPLOAD_DIR: 'uploads',
    });
    const disk = new DiskMediaStorage(config);

    const out = await disk.save({
      userId,
      kind: 'cover',
      buffer: Buffer.from('abc'),
      extension: '.png',
      mediaType: 'image/png',
    });

    expect(out.url).toMatch(
      new RegExp(
        `^http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/`,
      ),
    );
    expect(out.key).toMatch(
      new RegExp(`^${userId}/cover/[0-9]+-[a-f0-9-]+\\.png$`),
    );
    expect(mockedWriteFile).toHaveBeenCalled();
    const writtenPath = mockedWriteFile.mock.calls[0][0] as string;
    expect(writtenPath).toContain(`${userId}`);
    expect(writtenPath).toContain('cover');
    expect(writtenPath).toMatch(/\.png$/);
  });

  it('uses .jpg extension for jpeg mime extension param', async () => {
    const config = new ConfigService({
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:3000/uploads',
      MEDIA_UPLOAD_DIR: 'uploads',
    });
    const disk = new DiskMediaStorage(config);

    await disk.save({
      userId,
      kind: 'cover',
      buffer: Buffer.from('x'),
      extension: '.jpg',
      mediaType: 'image/jpeg',
    });

    const writtenPath = mockedWriteFile.mock.calls[0][0] as string;
    expect(writtenPath).toMatch(/\.jpg$/);
  });
});
