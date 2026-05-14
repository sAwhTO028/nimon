import { HttpStatus } from '@nestjs/common';
import { FREE_TIER_QUOTAS, FREE_TIER_QUOTA_KEYS } from './free-tier-quotas';
import { QuotaExceededException } from './quota-exceeded.exception';

describe('QuotaExceededException', () => {
  it('returns 403 with quota_exceeded contract body', () => {
    const ex = new QuotaExceededException(
      FREE_TIER_QUOTA_KEYS.publishedMonos,
      FREE_TIER_QUOTAS.publishedMonos,
      30,
    );
    expect(ex.getStatus()).toBe(HttpStatus.FORBIDDEN);
    expect(ex.getResponse()).toEqual({
      code: 'quota_exceeded',
      key: 'published_mono_limit_reached',
      limit: 30,
      current: 30,
    });
  });
});
