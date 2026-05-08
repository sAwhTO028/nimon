-- CreateTable
CREATE TABLE "creator_mono_collections" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "ownerId" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "coverImageUrl" TEXT,
    "visibility" TEXT NOT NULL DEFAULT 'public',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "creator_mono_collections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "creator_mono_collection_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "collectionId" UUID NOT NULL,
    "publishedMonoId" UUID NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "creator_mono_collection_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "creator_mono_collections_ownerId_sortOrder_createdAt_idx" ON "creator_mono_collections"("ownerId", "sortOrder", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "creator_mono_collection_items_collectionId_publishedMonoId_key" ON "creator_mono_collection_items"("collectionId", "publishedMonoId");

-- CreateIndex
CREATE INDEX "creator_mono_collection_items_publishedMonoId_idx" ON "creator_mono_collection_items"("publishedMonoId");

-- AddForeignKey
ALTER TABLE "creator_mono_collections" ADD CONSTRAINT "creator_mono_collections_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "creator_mono_collection_items" ADD CONSTRAINT "creator_mono_collection_items_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "creator_mono_collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "creator_mono_collection_items" ADD CONSTRAINT "creator_mono_collection_items_publishedMonoId_fkey" FOREIGN KEY ("publishedMonoId") REFERENCES "published_monos"("id") ON DELETE CASCADE ON UPDATE CASCADE;
