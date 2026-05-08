-- M9a: add profile cover image URL.

ALTER TABLE "user_profiles"
ADD COLUMN "coverImageUrl" TEXT;

