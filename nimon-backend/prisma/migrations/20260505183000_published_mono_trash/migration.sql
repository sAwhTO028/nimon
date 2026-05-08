-- AlterTable
ALTER TABLE "published_monos" ADD COLUMN "trashedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "published_monos_ownerId_trashedAt_idx" ON "published_monos"("ownerId", "trashedAt");
