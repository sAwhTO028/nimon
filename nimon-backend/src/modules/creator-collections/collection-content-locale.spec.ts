import { BadRequestException } from '@nestjs/common';

import {
  assertBulkCollectionContentLocaleCompatible,
  assertCollectionContentLocaleCompatible,
  normalizeCollectionContentLocaleInput,
  resolveCollectionContentLocaleForCreate,
} from './collection-content-locale';

describe('collection-content-locale', () => {
  it('resolveCollectionContentLocaleForCreate uses explicit then prefs then en', () => {
    expect(resolveCollectionContentLocaleForCreate('my', 'en')).toBe('my');
    expect(resolveCollectionContentLocaleForCreate(undefined, 'my')).toBe('my');
    expect(resolveCollectionContentLocaleForCreate(null, null)).toBe('en');
  });

  it('normalizeCollectionContentLocaleInput rejects invalid', () => {
    expect(() => normalizeCollectionContentLocaleInput('th')).toThrow(
      BadRequestException,
    );
  });

  it('assertCollectionContentLocaleCompatible allows legacy null collection', () => {
    expect(() =>
      assertCollectionContentLocaleCompatible(null, 'en'),
    ).not.toThrow();
    expect(() =>
      assertCollectionContentLocaleCompatible(null, null),
    ).not.toThrow();
  });

  it('assertCollectionContentLocaleCompatible rejects mismatch', () => {
    expect(() =>
      assertCollectionContentLocaleCompatible('my', 'en', 'mono-1'),
    ).toThrow(BadRequestException);
  });

  it('assertBulkCollectionContentLocaleCompatible fails whole batch', () => {
    expect(() =>
      assertBulkCollectionContentLocaleCompatible('my', [
        { id: 'a', contentLocale: 'my' },
        { id: 'b', contentLocale: 'en' },
      ]),
    ).toThrow(BadRequestException);
  });
});
