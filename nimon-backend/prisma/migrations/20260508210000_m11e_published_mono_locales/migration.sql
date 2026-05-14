-- AlterTable
ALTER TABLE "published_monos" ADD COLUMN "contentLocale" TEXT NOT NULL DEFAULT 'en',
ADD COLUMN "learningLanguage" TEXT NOT NULL DEFAULT 'ja';

-- CreateIndex
CREATE INDEX "published_monos_contentLocale_learningLanguage_updatedAt_idx" ON "published_monos"("contentLocale", "learningLanguage", "updatedAt");

