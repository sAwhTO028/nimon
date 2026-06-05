import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// Japanese furigana / kanji creator UX applies unless learning target is explicit `en`.
bool isJapaneseLearningDraft(CreatorStoryV1 draft) =>
    isJapaneseLearningWireCode(draft.basics.learningLanguage);

/// Explicit English learning target (`learningLanguage` wire `en`).
bool isEnglishLearningDraft(CreatorStoryV1 draft) {
  final t = (draft.basics.learningLanguage ?? '').trim().toLowerCase();
  return t == 'en';
}
