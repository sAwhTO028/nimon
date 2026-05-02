import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/draft_summary_completion.dart';

void main() {
  group('computeCheapDraftSummaryCompletionPercent', () {
    test('is bounded 0–100', () {
      final p = computeCheapDraftSummaryCompletionPercent(
        title: 'T',
        category: 'c',
        level: 'l',
        description: 'd',
        targetDurationBandKey: '3_5',
        sentenceCount: 100,
        moduleWorkflowStatuses: {
          'vocabulary_kanji': 'completed',
          'grammar': 'completed',
          'quiz': 'completed',
          'audio': 'completed',
        },
      );
      expect(p, inInclusiveRange(0, 100));
    });

    test('all not_started and empty basics yields low percent', () {
      final p = computeCheapDraftSummaryCompletionPercent(
        title: '',
        category: '',
        level: '',
        description: '',
        targetDurationBandKey: null,
        sentenceCount: 0,
        moduleWorkflowStatuses: {
          'vocabulary_kanji': 'not_started',
          'grammar': 'not_started',
          'quiz': 'not_started',
          'audio': 'not_started',
        },
      );
      expect(p, 0);
    });
  });
}
