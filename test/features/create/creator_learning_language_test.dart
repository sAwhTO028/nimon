import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/create/creator_learning_language.dart';
import 'package:nimon/features/create/story_v1_model.dart';

void main() {
  test('isJapaneseLearningWireCode legacy fallback', () {
    expect(isJapaneseLearningWireCode(null), isTrue);
    expect(isJapaneseLearningWireCode('ja'), isTrue);
    expect(isJapaneseLearningWireCode('en'), isFalse);
  });

  test('draft helpers', () {
    final ja = CreatorStoryV1.empty(learningLanguage: 'ja');
    final en = CreatorStoryV1.empty(learningLanguage: 'en');
    expect(isJapaneseLearningDraft(ja), isTrue);
    expect(isEnglishLearningDraft(ja), isFalse);
    expect(isJapaneseLearningDraft(en), isFalse);
    expect(isEnglishLearningDraft(en), isTrue);
  });
}
