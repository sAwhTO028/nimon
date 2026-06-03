import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// Minimal import note used when persisting AI prompt mode for legacy imported drafts.
const String kNimonImportAiPromptSourceNoteBackfill = '''
[nimon-import]
promptDataTab=AI_mode
''';

/// Stored prompt/source note on [StoryBasics] (no backfill).
String creatorDraftPromptSourceNoteStored(CreatorStoryV1 draft) =>
    draft.basics.promptSourceNote;

/// Effective note for readiness/publish: stored value, or safe AI backfill for JSON imports.
String effectiveCreatorDraftPromptSourceNote(CreatorStoryV1 draft) {
  final stored = creatorDraftPromptSourceNoteStored(draft).trim();
  if (stored.isNotEmpty) {
    if (_storedNoteImpliesManual(stored)) return stored;
    if (resolveHtmlPromptModeFromSourceNote(stored) == HtmlPromptMode.ai) {
      return creatorDraftPromptSourceNoteStored(draft);
    }
    if (stored.contains('[nimon-import]')) {
      return _mergeImportAiPromptTab(stored);
    }
    return stored;
  }
  if (draftQualifiesForImportAiPromptBackfill(draft)) {
    return kNimonImportAiPromptSourceNoteBackfill.trim();
  }
  return stored;
}

bool _storedNoteImpliesManual(String stored) {
  final lower = stored.toLowerCase();
  return lower.contains('promptdatatab=manual_mode') ||
      lower.contains('manual_mode');
}

String _mergeImportAiPromptTab(String stored) {
  if (stored.toLowerCase().contains('promptdatatab=')) return stored;
  return '$stored\npromptDataTab=AI_mode';
}

/// True when this draft likely came from hidden JSON import and should use AI HTML rules.
bool draftQualifiesForImportAiPromptBackfill(CreatorStoryV1 draft) {
  final stored = creatorDraftPromptSourceNoteStored(draft).trim();
  if (_storedNoteImpliesManual(stored)) return false;
  if (stored.toLowerCase().contains('promptdatatab=ai_mode')) return false;
  if (stored.contains('[nimon-import]')) return true;
  if (stored.isEmpty && _hasNimonJsonImportContentSignals(draft)) return true;
  return false;
}

bool _hasNimonJsonImportContentSignals(CreatorStoryV1 draft) {
  if (draft.sentences.isEmpty) return false;
  final sentenceAi = draft.sentences.any(
    (s) => s.provenance?.sourceMode == ContentSourceMode.aiDraft,
  );
  if (!sentenceAi) return false;
  final vocabAi = draft.vocabularyKanji.entries.any(
    (e) => e.provenance?.sourceMode == ContentSourceMode.aiDraft,
  );
  final quizAi = draft.quiz.entries.any(
    (e) => e.provenance?.sourceMode == ContentSourceMode.aiDraft,
  );
  return vocabAi || quizAi;
}

/// Applies AI prompt backfill to basics when needed (load/publish migration).
CreatorStoryV1 withBackfilledImportPromptSourceNote(CreatorStoryV1 draft) {
  final effective = effectiveCreatorDraftPromptSourceNote(draft).trim();
  if (effective == creatorDraftPromptSourceNoteStored(draft).trim()) {
    return draft;
  }
  return draft.copyWith(
    basics: draft.basics.copyWith(promptSourceNote: effective),
  );
}
