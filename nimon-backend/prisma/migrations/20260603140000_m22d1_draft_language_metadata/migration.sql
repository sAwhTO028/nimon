-- M22D-1: structured draft language metadata (community + learning target).

ALTER TABLE "story_drafts" ADD COLUMN "contentLocale" TEXT;
ALTER TABLE "story_drafts" ADD COLUMN "learningLanguage" TEXT;

-- Safe backfill: learning target defaults to ja; community left null (publish uses prefs fallback).
UPDATE "story_drafts" SET "learningLanguage" = 'ja' WHERE "learningLanguage" IS NULL;
