-- AlterTable
ALTER TABLE "creator_mono_collection_items" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "creator_mono_collections" ALTER COLUMN "id" DROP DEFAULT,
ALTER COLUMN "updatedAt" DROP DEFAULT;
