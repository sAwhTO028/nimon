import 'package:nimon/features/create/story_creator_models.dart';

/// V1: defensive filter to prevent accidental empty shell drafts from appearing
/// in draft management UIs (e.g. Profile > Processing).
bool isMeaningfulDraftForProcessing(CreatorStoryV1 d) {
  final b = d.basics;
  final title = b.title.trim();
  final desc = b.description.trim();
  final level = b.level.trim();
  final category = b.category.trim();
  final duration = (b.targetDurationBandKey ?? '').trim();
  final prompt = b.promptSourceNote.trim();
  final cover = (b.coverImageUrl ?? '').trim();

  final hasBasicsSignal = title.isNotEmpty ||
      desc.isNotEmpty ||
      level.isNotEmpty ||
      category.isNotEmpty ||
      duration.isNotEmpty ||
      prompt.isNotEmpty ||
      cover.isNotEmpty;

  if (hasBasicsSignal) return true;

  final hasStorySentences =
      d.sentences.any((s) => s.japaneseText.trim().isNotEmpty);
  if (hasStorySentences) return true;

  final hasVocab = d.vocabularyKanji.entries.any((e) => e.isValidV1);
  if (hasVocab) return true;

  final hasGrammar = d.grammar.entries.any((e) => e.isValidV1);
  if (hasGrammar) return true;

  final hasQuiz = d.quiz.entries.any((e) => e.isValidV1);
  if (hasQuiz) return true;

  final hasListening = d.audio.storyAudio?.isValidV1 == true;
  if (hasListening) return true;

  return false;
}
