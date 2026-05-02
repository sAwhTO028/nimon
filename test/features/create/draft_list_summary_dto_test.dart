import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_processing_copy.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/story_creator_models.dart';

void main() {
  group('DraftListSummaryDto.fromJson', () {
    test('parses extended summary row', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 'd1',
        'title': 'T',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'draft',
        'publishState': 'draft',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 3,
        'publishType': 'draft',
        'previewText': 'Hi',
        'targetDurationBandKey': '3_5',
        'moduleWorkflowStatuses': {
          'vocabulary_kanji': 'in_progress',
          'grammar': 'not_started',
          'quiz': 'not_started',
          'audio': 'not_started',
        },
        'learnModeEnabled': true,
        'completionPercent': 42,
        'workspaceState': 'draft',
        'lastEditingStep': 'vocabulary_kanji',
        'hasUnpublishedCoreChanges': false,
      });
      expect(d.targetDurationBandKey, '3_5');
      expect(d.moduleWorkflowStatuses['vocabulary_kanji'], 'in_progress');
      expect(d.learnModeEnabled, isTrue);
      expect(d.completionPercent, 42);
      expect(d.workspaceState, 'draft');
      expect(d.lastEditingStep, 'vocabulary_kanji');
      expect(
        CreatorProcessingCopy.draftSummaryDurationChip(d.targetDurationBandKey),
        '3–5 mins',
      );
    });

    test('legacy JSON without new fields still parses', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 'x',
        'title': 'Old',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'draft',
        'publishState': 'draft',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 2,
        'publishType': 'draft',
        'previewText': 'p',
      });
      expect(d.targetDurationBandKey, isNull);
      expect(d.moduleWorkflowStatuses.length, 4);
      expect(d.moduleWorkflowStatuses['vocabulary_kanji'], 'not_started');
      expect(d.learnModeEnabled, isFalse);
      expect(d.completionPercent, isNull);
      expect(d.workspaceState, 'draft');
      expect(d.lastEditingStep, isNull);
    });

    test('learnModeEnabled derived when omitted but modules started', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 'y',
        'title': 'T',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'draft',
        'publishState': 'draft',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 1,
        'publishType': 'draft',
        'previewText': 'p',
        'moduleWorkflowStatuses': {'quiz': 'completed'},
      });
      expect(d.learnModeEnabled, isTrue);
    });

    test('workspaceState falls back from publishState when omitted', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 'z',
        'title': 'T',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'published',
        'publishState': 'reading_only_published',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 1,
        'publishType': 'read_only',
        'previewText': 'p',
      });
      expect(d.workspaceState, 'editing');
      expect(d.hasUnpublishedCoreChanges, isNull);
    });

    test('parses synced published row', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 's1',
        'title': 'T',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'published',
        'publishState': 'reading_only_published',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 1,
        'publishType': 'read_only',
        'previewText': 'p',
        'hasUnpublishedCoreChanges': false,
        'workspaceState': 'synced',
      });
      expect(d.workspaceState, 'synced');
      expect(d.hasUnpublishedCoreChanges, isFalse);
      expect(effectiveDraftListWorkspaceState(d), 'synced');
    });

    test('published without dirty flag defaults to editing', () {
      final d = DraftListSummaryDto.fromJson({
        'draftId': 'legacy',
        'title': 'T',
        'coverImageUrl': null,
        'level': 'n5',
        'category': 'drama',
        'status': 'published',
        'publishState': 'full_learn_published',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 1,
        'publishType': 'full_learn',
        'previewText': 'p',
      });
      expect(effectiveDraftListWorkspaceState(d), 'editing');
    });

    test('completionPercent clamps into 0–100', () {
      final low = DraftListSummaryDto.fromJson({
        'draftId': 'a',
        'title': '',
        'coverImageUrl': null,
        'level': '',
        'category': '',
        'status': 'draft',
        'publishState': 'draft',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 0,
        'publishType': 'draft',
        'previewText': null,
        'completionPercent': -5,
      });
      expect(low.completionPercent, 0);

      final high = DraftListSummaryDto.fromJson({
        'draftId': 'b',
        'title': '',
        'coverImageUrl': null,
        'level': '',
        'category': '',
        'status': 'draft',
        'publishState': 'draft',
        'processingStatus': null,
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'sentenceCount': 0,
        'publishType': 'draft',
        'previewText': null,
        'completionPercent': 150,
      });
      expect(high.completionPercent, 100);
    });
  });

  group('effectiveDraftListWorkspaceState', () {
    test('uses explicit workspaceState when set', () {
      final d = DraftListSummaryDto(
        draftId: 'a',
        title: 't',
        level: 'n5',
        category: 'd',
        status: 'published',
        publishState: StoryPublishState.readingOnlyPublished.storageKey,
        sentenceCount: 1,
        publishType: 'read_only',
        workspaceState: 'synced',
        hasUnpublishedCoreChanges: true,
      );
      expect(effectiveDraftListWorkspaceState(d), 'synced');
    });
  });

  group('CreatorProcessingCopy draft summary helpers', () {
    test('readiness prefers completion percent over sentences', () {
      expect(
        CreatorProcessingCopy.draftSummaryReadinessLine(
          completionPercent: 55,
          sentenceCount: 10,
        ),
        '55% complete',
      );
    });

    test('draftSummaryLastEditingLabel maps module keys', () {
      expect(
        CreatorProcessingCopy.draftSummaryLastEditingLabel('grammar'),
        'Grammar',
      );
      expect(CreatorProcessingCopy.draftSummaryLastEditingLabel(''), '');
    });
  });
}
