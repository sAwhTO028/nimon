import { MulterExceptionFilter } from './multer-exception.filter';

describe('MulterExceptionFilter', () => {
  it('LIMIT_FILE_SIZE responds with validation_failed (cover route)', () => {
    process.env.MEDIA_COVER_MAX_BYTES = '10485760';
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const filter = new MulterExceptionFilter();
    filter.catch(
      { code: 'LIMIT_FILE_SIZE' },
      {
        switchToHttp: () => ({
          getResponse: () => ({ status }),
          getRequest: () => ({ originalUrl: '/v1/media/upload/cover' }),
        }),
      } as never,
    );
    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalled();
    const payload = json.mock.calls[0][0] as Record<string, unknown>;
    expect(payload['message']).toBe('validation_failed');
  });
});
