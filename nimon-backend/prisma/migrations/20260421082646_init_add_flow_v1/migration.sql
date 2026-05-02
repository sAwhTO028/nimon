-- CreateEnum
CREATE TYPE "PublishState" AS ENUM ('draft', 'reading_only_published', 'full_learn_published');

-- CreateEnum
CREATE TYPE "ModuleTaskStatus" AS ENUM ('not_started', 'in_progress', 'completed');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "email" TEXT,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "story_drafts" (
    "id" UUID NOT NULL,
    "ownerId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "schemaVersion" INTEGER NOT NULL DEFAULT 1,
    "version" INTEGER NOT NULL DEFAULT 1,
    "publishState" "PublishState" NOT NULL DEFAULT 'draft',
    "publishedMonoId" UUID,
    "readingOnlyPublishedAt" TIMESTAMP(3),
    "fullLearnPublishedAt" TIMESTAMP(3),
    "title" TEXT NOT NULL DEFAULT '',
    "category" TEXT NOT NULL DEFAULT '',
    "level" TEXT NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "promptSourceNote" TEXT NOT NULL DEFAULT '',
    "targetDurationBandKey" TEXT,
    "coverImageUrl" TEXT,
    "moduleWorkflowStatuses" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "story_drafts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draft_sentences" (
    "id" UUID NOT NULL,
    "draftId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "order" INTEGER NOT NULL,
    "content" JSONB NOT NULL,

    CONSTRAINT "draft_sentences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draft_vocab_entries" (
    "id" UUID NOT NULL,
    "draftId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "order" INTEGER NOT NULL,
    "content" JSONB NOT NULL,

    CONSTRAINT "draft_vocab_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draft_grammar_entries" (
    "id" UUID NOT NULL,
    "draftId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "order" INTEGER NOT NULL,
    "content" JSONB NOT NULL,

    CONSTRAINT "draft_grammar_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draft_quiz_entries" (
    "id" UUID NOT NULL,
    "draftId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "order" INTEGER NOT NULL,
    "content" JSONB NOT NULL,

    CONSTRAINT "draft_quiz_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draft_audio" (
    "id" UUID NOT NULL,
    "draftId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'storyAudio',
    "content" JSONB NOT NULL,

    CONSTRAINT "draft_audio_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "published_monos" (
    "id" UUID NOT NULL,
    "ownerId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "title" TEXT NOT NULL DEFAULT '',
    "category" TEXT NOT NULL DEFAULT '',
    "level" TEXT NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "content" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "published_monos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "story_drafts_ownerId_updatedAt_idx" ON "story_drafts"("ownerId", "updatedAt");

-- CreateIndex
CREATE INDEX "story_drafts_ownerId_publishState_idx" ON "story_drafts"("ownerId", "publishState");

-- CreateIndex
CREATE INDEX "draft_sentences_draftId_idx" ON "draft_sentences"("draftId");

-- CreateIndex
CREATE UNIQUE INDEX "draft_sentences_draftId_order_key" ON "draft_sentences"("draftId", "order");

-- CreateIndex
CREATE INDEX "draft_vocab_entries_draftId_idx" ON "draft_vocab_entries"("draftId");

-- CreateIndex
CREATE UNIQUE INDEX "draft_vocab_entries_draftId_order_key" ON "draft_vocab_entries"("draftId", "order");

-- CreateIndex
CREATE INDEX "draft_grammar_entries_draftId_idx" ON "draft_grammar_entries"("draftId");

-- CreateIndex
CREATE UNIQUE INDEX "draft_grammar_entries_draftId_order_key" ON "draft_grammar_entries"("draftId", "order");

-- CreateIndex
CREATE INDEX "draft_quiz_entries_draftId_idx" ON "draft_quiz_entries"("draftId");

-- CreateIndex
CREATE UNIQUE INDEX "draft_quiz_entries_draftId_order_key" ON "draft_quiz_entries"("draftId", "order");

-- CreateIndex
CREATE INDEX "draft_audio_draftId_idx" ON "draft_audio"("draftId");

-- CreateIndex
CREATE INDEX "published_monos_ownerId_updatedAt_idx" ON "published_monos"("ownerId", "updatedAt");

-- AddForeignKey
ALTER TABLE "story_drafts" ADD CONSTRAINT "story_drafts_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_drafts" ADD CONSTRAINT "story_drafts_publishedMonoId_fkey" FOREIGN KEY ("publishedMonoId") REFERENCES "published_monos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draft_sentences" ADD CONSTRAINT "draft_sentences_draftId_fkey" FOREIGN KEY ("draftId") REFERENCES "story_drafts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draft_vocab_entries" ADD CONSTRAINT "draft_vocab_entries_draftId_fkey" FOREIGN KEY ("draftId") REFERENCES "story_drafts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draft_grammar_entries" ADD CONSTRAINT "draft_grammar_entries_draftId_fkey" FOREIGN KEY ("draftId") REFERENCES "story_drafts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draft_quiz_entries" ADD CONSTRAINT "draft_quiz_entries_draftId_fkey" FOREIGN KEY ("draftId") REFERENCES "story_drafts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draft_audio" ADD CONSTRAINT "draft_audio_draftId_fkey" FOREIGN KEY ("draftId") REFERENCES "story_drafts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "published_monos" ADD CONSTRAINT "published_monos_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
