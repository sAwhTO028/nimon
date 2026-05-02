-- New drafts: hasUnpublishedCoreChanges defaults to false.
-- Existing published rows: treat as dirty until next publish clears the flag.
ALTER TABLE "story_drafts" ADD COLUMN "hasUnpublishedCoreChanges" BOOLEAN NOT NULL DEFAULT false;

UPDATE "story_drafts"
SET "hasUnpublishedCoreChanges" = true
WHERE "publishState" <> 'draft';
