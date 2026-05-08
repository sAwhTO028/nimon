import { UnsupportedMediaTypeException } from '@nestjs/common';
import type { MulterMemoryUploadedFile } from './media-upload.types';
import type { MediaStorage } from './media-storage';
import { MediaService } from './media.service';

function mockFile(
  overrides: Partial<MulterMemoryUploadedFile>,
): MulterMemoryUploadedFile {
  return {
    fieldname: 'file',
    originalname: 'test.png',
    encoding: '7bit',
    mimetype: 'image/png',
    size: 4,
    buffer: Buffer.from('data'),
    destination: '',
    filename: '',
    path: '',
    stream: null as never,
    ...overrides,
  };
}

describe('MediaService', () => {
  const userId = '11111111-1111-1111-1111-111111111111';

  let mockStorage: jest.Mocked<MediaStorage>;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.MEDIA_PUBLIC_BASE_URL = 'http://localhost:3000/uploads';
    process.env.MEDIA_UPLOAD_DIR = 'uploads';
    process.env.MEDIA_COVER_MAX_BYTES = '10485760';
    process.env.MEDIA_AUDIO_MAX_BYTES = '52428800';
    mockStorage = {
      save: jest.fn(),
    };
  });

  function svc() {
    return new MediaService(mockStorage);
  }

  it('saveCover returns url, mediaType, originalName, sizeBytes, durationSeconds null', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/cover/fake.png`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/fake.png`,
    });

    const f = mockFile({
      originalname: 'cover.png',
      mimetype: 'image/png',
      size: 4,
    });

    const out = await svc().saveCover(userId, f);

    expect(out.url).toMatch(
      new RegExp(
        `^http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/`,
      ),
    );
    expect(out.mediaType).toBe('image/png');
    expect(out.originalName).toBe('cover.png');
    expect(out.sizeBytes).toBe(4);
    expect(out.durationSeconds).toBeNull();
    expect(mockStorage.save).toHaveBeenCalledWith({
      userId,
      kind: 'cover',
      buffer: f.buffer,
      extension: '.png',
      mediaType: 'image/png',
    });
  });

  it('saveAudio returns url, mediaType, originalName, sizeBytes', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/fake.mp3`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/fake.mp3`,
    });

    const f = mockFile({
      originalname: 'story.mp3',
      mimetype: 'audio/mpeg',
      size: 8,
      buffer: Buffer.from('12345678'),
    });

    const out = await svc().saveAudio(userId, f);

    expect(out.url).toContain(`/audio/`);
    expect(out.mediaType).toBe('audio/mpeg');
    expect(out.originalName).toBe('story.mp3');
    expect(out.sizeBytes).toBe(8);
    expect(out.durationSeconds).toBeNull();
    expect(mockStorage.save).toHaveBeenCalledWith({
      userId,
      kind: 'audio',
      buffer: f.buffer,
      extension: '.mp3',
      mediaType: 'audio/mpeg',
    });
  });

  it('saveAudio accepts audio/mp3 and returns canonical audio/mpeg', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/x.mp3`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.mp3`,
    });

    const f = mockFile({
      originalname: 'song.mp3',
      mimetype: 'audio/mp3',
      buffer: Buffer.from('12345678'),
    });

    const out = await svc().saveAudio(userId, f);

    expect(out.mediaType).toBe('audio/mpeg');
    expect(mockStorage.save).toHaveBeenCalledWith(
      expect.objectContaining({
        extension: '.mp3',
        mediaType: 'audio/mpeg',
      }),
    );
  });

  it('saveAudio accepts application/octet-stream with song.mp3', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/x.mp3`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.mp3`,
    });

    const f = mockFile({
      originalname: 'song.mp3',
      mimetype: 'application/octet-stream',
      buffer: Buffer.from('12345678'),
    });

    const out = await svc().saveAudio(userId, f);

    expect(out.mediaType).toBe('audio/mpeg');
    expect(mockStorage.save).toHaveBeenCalledWith(
      expect.objectContaining({ mediaType: 'audio/mpeg', extension: '.mp3' }),
    );
  });

  it('saveAudio accepts application/octet-stream with song.m4a', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/x.m4a`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.m4a`,
    });

    const f = mockFile({
      originalname: 'song.m4a',
      mimetype: 'application/octet-stream',
      buffer: Buffer.from('12345678'),
    });

    const out = await svc().saveAudio(userId, f);

    expect(out.mediaType).toBe('audio/mp4');
    expect(mockStorage.save).toHaveBeenCalledWith(
      expect.objectContaining({ mediaType: 'audio/mp4', extension: '.m4a' }),
    );
  });

  it('saveAudio accepts application/octet-stream with song.wav', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/x.wav`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.wav`,
    });

    const f = mockFile({
      originalname: 'song.wav',
      mimetype: 'application/octet-stream',
      buffer: Buffer.from('12345678'),
    });

    const out = await svc().saveAudio(userId, f);

    expect(out.mediaType).toBe('audio/wav');
    expect(mockStorage.save).toHaveBeenCalledWith(
      expect.objectContaining({ mediaType: 'audio/wav', extension: '.wav' }),
    );
  });

  it('saveAudio accepts audio/x-wav and audio/vnd.wave as canonical audio/wav', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/audio/x.wav`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.wav`,
    });

    for (const mt of ['audio/x-wav', 'audio/vnd.wave']) {
      jest.clearAllMocks();
      mockStorage.save.mockResolvedValue({
        key: `${userId}/audio/x.wav`,
        url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/audio/x.wav`,
      });
      const f = mockFile({
        originalname: 'clip.wav',
        mimetype: mt,
        buffer: Buffer.from('abcd'),
      });
      const out = await svc().saveAudio(userId, f);
      expect(out.mediaType).toBe('audio/wav');
      expect(mockStorage.save).toHaveBeenCalledWith(
        expect.objectContaining({
          mediaType: 'audio/wav',
          extension: '.wav',
        }),
      );
    }
  });

  it('saveAudio rejects application/octet-stream with file.pdf', async () => {
    const f = mockFile({
      originalname: 'file.pdf',
      mimetype: 'application/octet-stream',
      buffer: Buffer.from('%PDF'),
    });

    await expect(svc().saveAudio(userId, f)).rejects.toBeInstanceOf(
      UnsupportedMediaTypeException,
    );
    expect(mockStorage.save).not.toHaveBeenCalled();
  });

  it('rejects invalid cover mime', async () => {
    const f = mockFile({ mimetype: 'application/pdf' });

    await expect(svc().saveCover(userId, f)).rejects.toBeInstanceOf(
      UnsupportedMediaTypeException,
    );
    expect(mockStorage.save).not.toHaveBeenCalled();
  });

  it('saveCover accepts image/jpg and returns canonical image/jpeg', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/cover/x.jpg`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/x.jpg`,
    });

    const f = mockFile({
      originalname: 'photo.jpg',
      mimetype: 'image/jpg',
    });

    const out = await svc().saveCover(userId, f);

    expect(out.mediaType).toBe('image/jpeg');
    expect(mockStorage.save).toHaveBeenCalledWith(
      expect.objectContaining({
        extension: '.jpg',
        mediaType: 'image/jpeg',
      }),
    );
  });

  it('saveCover accepts application/octet-stream when originalName ends with .jpg', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/cover/x.jpg`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/x.jpg`,
    });

    const f = mockFile({
      originalname: 'photo.jpg',
      mimetype: 'application/octet-stream',
    });

    const out = await svc().saveCover(userId, f);

    expect(out.mediaType).toBe('image/jpeg');
    expect(mockStorage.save).toHaveBeenCalled();
  });

  it('saveCover accepts empty mimetype when originalName ends with .jpeg', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/cover/x.jpg`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/x.jpg`,
    });

    const f = mockFile({
      originalname: 'photo.jpeg',
      mimetype: '',
    });

    const out = await svc().saveCover(userId, f);

    expect(out.mediaType).toBe('image/jpeg');
    expect(mockStorage.save).toHaveBeenCalled();
  });

  it('saveCover rejects application/octet-stream with photo.pdf', async () => {
    const f = mockFile({
      originalname: 'photo.pdf',
      mimetype: 'application/octet-stream',
    });

    await expect(svc().saveCover(userId, f)).rejects.toBeInstanceOf(
      UnsupportedMediaTypeException,
    );
    expect(mockStorage.save).not.toHaveBeenCalled();
  });

  it('rejects invalid audio mime', async () => {
    const f = mockFile({ mimetype: 'image/png', buffer: Buffer.from('x') });

    await expect(svc().saveAudio(userId, f)).rejects.toBeInstanceOf(
      UnsupportedMediaTypeException,
    );
    expect(mockStorage.save).not.toHaveBeenCalled();
  });

  it('sanitizes dangerous original names in response', async () => {
    mockStorage.save.mockResolvedValue({
      key: `${userId}/cover/x.jpg`,
      url: `http://localhost:3000/uploads/${encodeURIComponent(userId)}/cover/x.jpg`,
    });

    const f = mockFile({
      originalname: '../../../etc/passwd',
      mimetype: 'image/jpeg',
    });

    const out = await svc().saveCover(userId, f);
    expect(out.originalName).not.toContain('..');
    expect(out.originalName).not.toContain('/');
  });
});
