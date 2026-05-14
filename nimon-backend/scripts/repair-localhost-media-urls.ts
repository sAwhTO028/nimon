/**
 * One-time (optional) DB repair: rewrite loopback / relative upload URLs in stored fields
 * to the current MEDIA_PUBLIC_BASE_URL. Default is **dry-run**; pass `--write` to persist.
 *
 * Run from `nimon-backend` (requires DATABASE_URL, uses same Prisma + pg adapter as the app):
 *   pnpm exec ts-node --transpileOnly scripts/repair-localhost-media-urls.ts
 *   pnpm exec ts-node --transpileOnly scripts/repair-localhost-media-urls.ts --write
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';
import {
  canonicalizeMediaUrl,
  clonePublishedContentWithCanonicalMedia,
  normalizeMediaPublicBaseUrl,
} from '../src/modules/media/media-url-canonicalizer';

const write = process.argv.includes('--write');
const base = normalizeMediaPublicBaseUrl(process.env.MEDIA_PUBLIC_BASE_URL);

type Counts = {
  published_monos_content: number;
  user_profiles: number;
  creator_mono_collections: number;
};

async function main(): Promise<void> {
  const cs =
    process.env.DATABASE_URL ??
    'postgresql://nimon:nimon@localhost:5432/nimon?schema=public';
  const pool = new pg.Pool({ connectionString: cs });
  const prisma = new PrismaClient({
    adapter: new PrismaPg(pool),
  });

  const counts: Counts = {
    published_monos_content: 0,
    user_profiles: 0,
    creator_mono_collections: 0,
  };

  try {
    const monos = await prisma.publishedMono.findMany({
      select: { id: true, content: true },
    });
    for (const row of monos) {
      const next = clonePublishedContentWithCanonicalMedia(row.content, base);
      if (JSON.stringify(next) !== JSON.stringify(row.content)) {
        counts.published_monos_content += 1;
        if (write) {
          await prisma.publishedMono.update({
            where: { id: row.id },
            data: { content: next as object },
          });
        }
      }
    }

    const profiles = await prisma.userProfile.findMany({
      select: { userId: true, avatarUrl: true, coverImageUrl: true },
    });
    for (const p of profiles) {
      const av = canonicalizeMediaUrl(p.avatarUrl, base);
      const cv = canonicalizeMediaUrl(p.coverImageUrl, base);
      if (av !== p.avatarUrl || cv !== p.coverImageUrl) {
        counts.user_profiles += 1;
        if (write) {
          await prisma.userProfile.update({
            where: { userId: p.userId },
            data: { avatarUrl: av, coverImageUrl: cv },
          });
        }
      }
    }

    const collections = await prisma.creatorMonoCollection.findMany({
      select: { id: true, coverImageUrl: true },
    });
    for (const c of collections) {
      const next = canonicalizeMediaUrl(c.coverImageUrl, base);
      if (next !== c.coverImageUrl) {
        counts.creator_mono_collections += 1;
        if (write) {
          await prisma.creatorMonoCollection.update({
            where: { id: c.id },
            data: { coverImageUrl: next },
          });
        }
      }
    }

    console.log(
      JSON.stringify(
        {
          mode: write ? 'write' : 'dry-run',
          mediaPublicBaseUrl: base,
          rowsNeedingUpdate: counts,
        },
        null,
        2,
      ),
    );
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
