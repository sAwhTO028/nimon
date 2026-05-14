import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';
import {
  assertCanRevealOnePublishedTabMono,
  countOwnerPublishedTabVisibleMonos,
  countPublishedTabVisibleMonos,
  isOwnerPublishedMonoTabVisible,
  logPublishedTabPublishQuotaIfDev,
} from './published-mono-published-tab-quota';

describe('published-mono-published-tab-quota (M17E-7)', () => {
  const ownerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  it('countOwnerPublishedTabVisibleMonos uses the same where as owner Published tab list', async () => {
    const count = jest.fn().mockResolvedValue(12);
    const n = await countOwnerPublishedTabVisibleMonos({ publishedMono: { count } }, ownerId);
    expect(n).toBe(12);
    expect(count).toHaveBeenCalledWith({
      where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
    });
  });

  it('countPublishedTabVisibleMonos is an alias of countOwnerPublishedTabVisibleMonos', async () => {
    const count = jest.fn().mockResolvedValue(3);
    const n = await countPublishedTabVisibleMonos({ publishedMono: { count } }, ownerId);
    expect(n).toBe(3);
    expect(count).toHaveBeenCalledWith({
      where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
    });
  });

  it('isOwnerPublishedMonoTabVisible checks id + owner + catalog predicate', async () => {
    const count = jest.fn().mockResolvedValue(1);
    const monoId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    const v = await isOwnerPublishedMonoTabVisible({ publishedMono: { count } }, ownerId, monoId);
    expect(v).toBe(true);
    expect(count).toHaveBeenCalledWith({
      where: { id: monoId, ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
    });
  });

  it('assertCanRevealOnePublishedTabMono throws when visible is 30 (next 31)', async () => {
    const count = jest.fn().mockResolvedValue(30);
    try {
      await assertCanRevealOnePublishedTabMono(
        { publishedMono: { count } },
        ownerId,
        { tag: 'publish-quota', draftId: 'd1' },
      );
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toEqual({
        code: 'quota_exceeded',
        key: FREE_TIER_QUOTA_KEYS.publishedMonos,
        limit: FREE_TIER_QUOTAS.publishedMonos,
        current: 30,
      });
    }
  });

  it('assertCanRevealOnePublishedTabMono allows when visible is 29', async () => {
    const count = jest.fn().mockResolvedValue(29);
    const out = await assertCanRevealOnePublishedTabMono(
      { publishedMono: { count } },
      ownerId,
      { tag: 'publish-quota' },
    );
    expect(out).toEqual({ current: 29, nextVisibleCount: 30 });
  });

  it('assertCanRevealOnePublishedTabMono allows when visible is 28', async () => {
    const count = jest.fn().mockResolvedValue(28);
    const out = await assertCanRevealOnePublishedTabMono(
      { publishedMono: { count } },
      ownerId,
      { tag: 'publish-quota' },
    );
    expect(out).toEqual({ current: 28, nextVisibleCount: 29 });
  });

  it('PUBLISHED_MONO_CATALOG_VISIBLE excludes trashed rows (trashedAt null in predicate)', () => {
    expect(PUBLISHED_MONO_CATALOG_VISIBLE).toMatchObject({ trashedAt: null });
  });

  it('PUBLISHED_MONO_CATALOG_VISIBLE excludes edit-staged rows (linked draft with unpublished changes)', () => {
    expect(PUBLISHED_MONO_CATALOG_VISIBLE.NOT).toEqual({
      drafts: { some: { hasUnpublishedCoreChanges: true } },
    });
  });

  it('logPublishedTabPublishQuotaIfDev does not throw in test env', async () => {
    const count = jest.fn().mockResolvedValue(30);
    const log = jest.fn();
    await logPublishedTabPublishQuotaIfDev(
      { publishedMono: { count } },
      ownerId,
      { tag: 'publish-quota', publishedMonoId: 'p1' },
      log,
      false,
    );
    expect(log).toHaveBeenCalledWith(
      expect.stringContaining('visiblePublishedCount=30 nextVisibleCount=30'),
    );
    expect(log.mock.calls[0][0]).toContain('willBlock=false');
  });
});
