-- AlterTable: reading preferences (M11i)
ALTER TABLE "user_preferences" ADD COLUMN "readingTextSize" TEXT;
ALTER TABLE "user_preferences" ADD COLUMN "showExplanations" BOOLEAN;

-- Feed compatibility: treat legacy / incomplete rows as wildcard when null
ALTER TABLE "published_monos" ALTER COLUMN "contentLocale" DROP NOT NULL;
ALTER TABLE "published_monos" ALTER COLUMN "learningLanguage" DROP NOT NULL;

UPDATE "published_monos" SET "contentLocale" = 'en' WHERE "contentLocale" IS NULL;
UPDATE "published_monos" SET "learningLanguage" = 'ja' WHERE "learningLanguage" IS NULL;
