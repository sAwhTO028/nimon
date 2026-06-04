-- M22F-2: collection community metadata + safe backfill from visible items.

ALTER TABLE "creator_mono_collections" ADD COLUMN "contentLocale" TEXT;

-- Backfill: when every catalog-visible item shares one non-null contentLocale, stamp collection.
WITH visible_items AS (
  SELECT
    ci."collectionId" AS collection_id,
    pm."contentLocale" AS locale
  FROM "creator_mono_collection_items" ci
  INNER JOIN "published_monos" pm ON pm."id" = ci."publishedMonoId"
  WHERE pm."trashedAt" IS NULL
),
agg AS (
  SELECT
    collection_id,
    COUNT(*)::int AS item_count,
    COUNT(DISTINCT locale)::int AS distinct_locale_count,
    MIN(locale) AS min_locale,
    COUNT(*) FILTER (WHERE locale IS NOT NULL)::int AS non_null_count
  FROM visible_items
  GROUP BY collection_id
)
UPDATE "creator_mono_collections" c
SET "contentLocale" = agg.min_locale
FROM agg
WHERE c."id" = agg.collection_id
  AND agg.item_count > 0
  AND agg.non_null_count = agg.item_count
  AND agg.distinct_locale_count = 1
  AND agg.min_locale IS NOT NULL;
