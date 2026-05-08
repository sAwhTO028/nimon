-- Enforce product rule: one published mono belongs to at most one creator collection.

-- 1) Clean up any accidental duplicates (keep newest by createdAt).
WITH ranked AS (
  SELECT
    "id",
    ROW_NUMBER() OVER (
      PARTITION BY "publishedMonoId"
      ORDER BY "createdAt" DESC, "id" DESC
    ) AS rn
  FROM "creator_mono_collection_items"
)
DELETE FROM "creator_mono_collection_items"
WHERE "id" IN (SELECT "id" FROM ranked WHERE rn > 1);

-- 2) Drop old unique (collectionId, publishedMonoId)
DROP INDEX IF EXISTS "creator_mono_collection_items_collectionId_publishedMonoId_key";

-- 3) Add unique (publishedMonoId)
CREATE UNIQUE INDEX "creator_mono_collection_items_publishedMonoId_key"
ON "creator_mono_collection_items"("publishedMonoId");

