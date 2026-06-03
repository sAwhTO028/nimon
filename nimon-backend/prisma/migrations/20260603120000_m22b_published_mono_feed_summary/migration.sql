-- M22B: denormalized feed summary columns (avoid reading full content JSONB in catalog feed list).

ALTER TABLE "published_monos" ADD COLUMN "coverImageUrl" TEXT;
ALTER TABLE "published_monos" ADD COLUMN "publishKind" TEXT;
ALTER TABLE "published_monos" ADD COLUMN "hasAudio" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "published_monos" ADD COLUMN "sentenceCount" INTEGER;
ALTER TABLE "published_monos" ADD COLUMN "vocabCount" INTEGER;
ALTER TABLE "published_monos" ADD COLUMN "grammarCount" INTEGER;
ALTER TABLE "published_monos" ADD COLUMN "quizCount" INTEGER;

-- Backfill from existing content JSONB where possible.
UPDATE "published_monos"
SET
  "coverImageUrl" = NULLIF(TRIM("content" #>> '{core,coverImageUrl}'), ''),
  "publishKind" = NULLIF(TRIM("content" ->> 'publishKind'), ''),
  "hasAudio" = CASE
    WHEN COALESCE(NULLIF(TRIM("content" #>> '{learn,audio,storyAudio,sourceUrl}'), ''), '') <> ''
    THEN true
    ELSE false
  END,
  "sentenceCount" = CASE
    WHEN jsonb_typeof("content" #> '{core,sentences}') = 'array'
    THEN jsonb_array_length("content" #> '{core,sentences}')
    ELSE NULL
  END,
  "vocabCount" = CASE
    WHEN jsonb_typeof("content" #> '{learn,vocabularyKanji,entries}') = 'array'
    THEN jsonb_array_length("content" #> '{learn,vocabularyKanji,entries}')
    ELSE NULL
  END,
  "grammarCount" = CASE
    WHEN jsonb_typeof("content" #> '{learn,grammar,entries}') = 'array'
    THEN jsonb_array_length("content" #> '{learn,grammar,entries}')
    ELSE NULL
  END,
  "quizCount" = CASE
    WHEN jsonb_typeof("content" #> '{learn,quiz,entries}') = 'array'
    THEN jsonb_array_length("content" #> '{learn,quiz,entries}')
    ELSE NULL
  END;
