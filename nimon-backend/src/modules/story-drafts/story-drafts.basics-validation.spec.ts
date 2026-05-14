import { BadRequestException } from '@nestjs/common';
import { PublishState } from '@prisma/client';
import { StoryDraftsService } from './story-drafts.service';

describe('StoryDraftsService draft basics validation', () => {
  const ownerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const draftId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  it('updateDraft rejects unsafe title with validation_failed before touching prisma', async () => {
    const prisma = {
      $transaction: jest.fn(),
    } as any;

    const svc = new StoryDraftsService(prisma);

    await expect(
      svc.updateDraft(
        ownerId,
        draftId,
        {
          schemaVersion: 1,
          basics: {
            storyId: draftId,
            title: '<script>x</script>',
            category: 'drama',
            level: 'N5',
            description: '',
            promptSourceNote: '',
          },
          sentences: [],
          vocabularyKanji: { entries: [] },
          grammar: { entries: [] },
          quiz: { entries: [] },
          audio: { storyAudio: null },
          publishState: PublishState.draft,
          moduleWorkflowStatuses: {},
        } as any,
        '"v1"',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('publishReadOnly rejects missing title with validation_failed', async () => {
    const draftRow = {
      id: draftId,
      ownerId,
      version: 3,
      publishState: PublishState.draft,
      publishedMonoId: null,
      title: '',
      category: 'drama',
      level: 'N5',
      description: 'Some description',
      promptSourceNote: '',
      targetDurationBandKey: '3_5',
      coverImageUrl: null,
      readingOnlyPublishedAt: null,
      fullLearnPublishedAt: null,
      moduleWorkflowStatuses: {},
      sentences: [
        {
          order: 0,
          content: {
            japaneseText: 'あ'.repeat(12),
            meanings: ['hello'],
          },
        },
      ],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
      publishedMono: null,
    };

    const prisma = {
      $transaction: jest.fn(async (fn: (tx: any) => unknown) =>
        fn({
          storyDraft: {
            findFirst: jest.fn().mockResolvedValueOnce(draftRow),
            updateMany: jest.fn(),
          },
          publishedMono: {
            create: jest.fn(),
            findUnique: jest.fn(),
            update: jest.fn(),
          },
        }),
      ),
    } as any;

    const svc = new StoryDraftsService(prisma);

    let caught: unknown;
    try {
      await svc.publishReadOnly(ownerId, draftId, '"v3"');
    } catch (e) {
      caught = e;
    }

    expect(caught).toBeInstanceOf(BadRequestException);
    const body = (caught as BadRequestException).getResponse() as Record<
      string,
      unknown
    >;
    expect(body['message']).toBe('validation_failed');
    const issues = body['issues'] as Array<{ field?: string }>;
    expect(Array.isArray(issues)).toBe(true);
    expect(issues.some((i) => i.field === 'story.title')).toBe(true);
  });
});
