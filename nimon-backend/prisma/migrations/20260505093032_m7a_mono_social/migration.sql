-- CreateTable
CREATE TABLE "mono_bookmarks" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "publishedMonoId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mono_bookmarks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mono_reactions" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "publishedMonoId" UUID NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'heart',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mono_reactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "mono_bookmarks_userId_createdAt_idx" ON "mono_bookmarks"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "mono_bookmarks_publishedMonoId_idx" ON "mono_bookmarks"("publishedMonoId");

-- CreateIndex
CREATE UNIQUE INDEX "mono_bookmarks_userId_publishedMonoId_key" ON "mono_bookmarks"("userId", "publishedMonoId");

-- CreateIndex
CREATE INDEX "mono_reactions_publishedMonoId_idx" ON "mono_reactions"("publishedMonoId");

-- CreateIndex
CREATE UNIQUE INDEX "mono_reactions_userId_publishedMonoId_key" ON "mono_reactions"("userId", "publishedMonoId");

-- AddForeignKey
ALTER TABLE "mono_bookmarks" ADD CONSTRAINT "mono_bookmarks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mono_bookmarks" ADD CONSTRAINT "mono_bookmarks_publishedMonoId_fkey" FOREIGN KEY ("publishedMonoId") REFERENCES "published_monos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mono_reactions" ADD CONSTRAINT "mono_reactions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mono_reactions" ADD CONSTRAINT "mono_reactions_publishedMonoId_fkey" FOREIGN KEY ("publishedMonoId") REFERENCES "published_monos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
