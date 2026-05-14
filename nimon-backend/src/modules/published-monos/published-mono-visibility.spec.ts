import {
  PUBLISHED_MONO_CATALOG_VISIBLE,
  PUBLISHED_MONO_QUOTA_CONSUMING,
} from './published-mono-visibility';

describe('published-mono-visibility (M17E-2)', () => {
  it('PUBLISHED_MONO_QUOTA_CONSUMING counts active slots including edit-staged (no draft hide clause)', () => {
    expect(PUBLISHED_MONO_QUOTA_CONSUMING).toEqual({ trashedAt: null });
  });

  it('PUBLISHED_MONO_CATALOG_VISIBLE still excludes trashed and dirty-draft hidden rows', () => {
    expect(PUBLISHED_MONO_CATALOG_VISIBLE).toMatchObject({
      trashedAt: null,
      NOT: {
        drafts: {
          some: { hasUnpublishedCoreChanges: true },
        },
      },
    });
  });
});
