import 'dart:convert';

import 'package:nimon/features/create/creator_read_only_publish_tracking.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRoBaselineKeyPrefix = 'nimon_pub_edit_ro_baseline_v2_';
const String _kFlBaselineKeyPrefix = 'nimon_pub_edit_fl_baseline_v1_';

String _roBaselineKey(String draftId) =>
    '$_kRoBaselineKeyPrefix${draftId.trim()}';
String _flBaselineKey(String draftId) =>
    '$_kFlBaselineKeyPrefix${draftId.trim()}';

Map<String, Object?> _meaningsMap(LocalizedMeanings? m) {
  if (m == null) return const {};
  return {
    'en': (m.en ?? '').trim(),
    'my': (m.my ?? '').trim(),
    'byLanguage': {
      for (final k in m.byLanguage.keys.toList()..sort())
        k: m.byLanguage[k] ?? '',
    },
  };
}

Map<String, Object?> _sentenceBaselineMap(StorySentenceItem s) {
  final spans = [...s.furiganaSpans]..sort((a, b) {
      final c = a.start.compareTo(b.start);
      if (c != 0) return c;
      return a.end.compareTo(b.end);
    });
  return {
    'orderIndex': s.orderIndex,
    'japaneseText': s.japaneseText.trim(),
    'reading': (s.reading ?? '').trim(),
    'furiganaSpans': [
      for (final f in spans)
        if (f.isValid)
          {'start': f.start, 'end': f.end, 'reading': f.reading.trim()},
    ],
    'meanings': _meaningsMap(s.meanings),
  };
}

/// Serializable read-only / reader-facing core (basics + sentence text, readings, furigana, meanings).
Map<String, Object?> readOnlyEditBaselinePayload(CreatorStoryV1 d) {
  final b = d.basics;
  final sentences = [...d.sentences]
    ..sort((a, c) => a.orderIndex.compareTo(c.orderIndex));
  return {
    'title': b.title.trim(),
    'category': b.category.trim(),
    'level': b.level.trim(),
    'description': b.description.trim(),
    'promptSourceNote': b.promptSourceNote.trim(),
    'targetDurationBandKey': (b.targetDurationBandKey ?? '').trim(),
    'coverImageUrl': (b.coverImageUrl ?? '').trim(),
    'sentences': [for (final s in sentences) _sentenceBaselineMap(s)],
  };
}

/// Stable base64 signature for **read-only published** comparison (v2).
String computeReadOnlyEditBaselineSignature(CreatorStoryV1 d) {
  return base64Url
      .encode(utf8.encode(jsonEncode(readOnlyEditBaselinePayload(d))));
}

Map<String, Object?> _vocabEntryMap(VocabularyKanjiEntry e) {
  final pairs = e.effectiveExamplePairs
      .map((p) => {
            'source': p.sourceExample.trim(),
            'english': p.englishExample.trim(),
          })
      .toList();
  return {
    'id': e.id.trim(),
    'termJapanese': e.termJapanese.trim(),
    'type': e.type.storageKey,
    'reading': (e.reading ?? '').trim(),
    'glosses': _meaningsMap(e.glosses),
    'exampleSentence': (e.exampleSentence ?? '').trim(),
    'exampleMeanings': _meaningsMap(e.exampleMeanings),
    'examplePairs': pairs,
  };
}

Map<String, Object?> _grammarExampleMap(GrammarExample ex) {
  return {
    'japanese': ex.japanese.trim(),
    'meanings': _meaningsMap(ex.meanings),
  };
}

Map<String, Object?> _grammarEntryMap(GrammarEntry e) {
  return {
    'id': e.id.trim(),
    'headline': e.headline.trim(),
    'form': (e.form ?? '').trim(),
    'meanings': _meaningsMap(e.meanings),
    'usage': _meaningsMap(e.usage),
    'examples': [for (final ex in e.examples) _grammarExampleMap(ex)],
    'mistakeWrong': (e.mistakeWrong ?? '').trim(),
    'mistakeCorrect': (e.mistakeCorrect ?? '').trim(),
    'relatedNote': _meaningsMap(e.relatedNote),
  };
}

Map<String, Object?> _quizEntryMap(QuizEntry e) {
  return {
    'id': e.id.trim(),
    'category': e.category.storageKey,
    'prompt': e.prompt.trim(),
    'options': [for (final o in e.options) o.trim()],
    'correctIndex': e.correctIndex,
    'explanations': _meaningsMap(e.explanations),
    'sourceNote': (e.sourceNote ?? '').trim(),
  };
}

Map<String, Object?>? _storyAudioMap(StoryAudioAsset? a) {
  if (a == null) return null;
  return {
    'id': a.id.trim(),
    'sourceUrl': (a.sourceUrl ?? '').trim(),
    'localFileName': (a.localFileName ?? '').trim(),
    'displayName': (a.displayName ?? '').trim(),
    'durationSeconds': a.durationSeconds,
  };
}

/// Full learn baseline: read-only payload + learn layers (v1).
Map<String, Object?> fullLearnEditBaselinePayload(CreatorStoryV1 d) {
  final vocab = [...d.vocabularyKanji.entries]
    ..sort((a, b) => a.id.compareTo(b.id));
  final grammar = [...d.grammar.entries]..sort((a, b) => a.id.compareTo(b.id));
  final quiz = [...d.quiz.entries]..sort((a, b) => a.id.compareTo(b.id));
  return {
    'readOnly': readOnlyEditBaselinePayload(d),
    'vocabularyKanji': [for (final e in vocab) _vocabEntryMap(e)],
    'grammar': [for (final e in grammar) _grammarEntryMap(e)],
    'quiz': [for (final e in quiz) _quizEntryMap(e)],
    'storyAudio': _storyAudioMap(d.audio.storyAudio),
  };
}

String computeFullLearnEditBaselineSignature(CreatorStoryV1 d) {
  return base64Url
      .encode(utf8.encode(jsonEncode(fullLearnEditBaselinePayload(d))));
}

// ---------------------------------------------------------------------------
// Persistence (updated only after successful RO / FL publish — not ordinary save)
// ---------------------------------------------------------------------------

Future<String?> loadPublishedEditReadOnlyBaseline(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return null;
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_roBaselineKey(id));
  return v?.trim().isEmpty == true ? null : v?.trim();
}

Future<void> savePublishedEditReadOnlyBaseline(
    String draftId, String signature) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final sig = signature.trim();
  if (sig.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.setString(_roBaselineKey(id), sig);
}

Future<void> clearPublishedEditReadOnlyBaseline(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.remove(_roBaselineKey(id));
}

Future<String?> loadPublishedEditFullLearnBaseline(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return null;
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_flBaselineKey(id));
  return v?.trim().isEmpty == true ? null : v?.trim();
}

Future<void> savePublishedEditFullLearnBaseline(
    String draftId, String signature) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final sig = signature.trim();
  if (sig.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.setString(_flBaselineKey(id), sig);
}

Future<void> clearPublishedEditFullLearnBaseline(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.remove(_flBaselineKey(id));
}

Future<void> clearPublishedEditBaselines(String draftId) async {
  await clearPublishedEditReadOnlyBaseline(draftId);
  await clearPublishedEditFullLearnBaseline(draftId);
}

bool _baselineDiff(String? baseline, String current) {
  final b = baseline?.trim();
  if (b == null || b.isEmpty) return false;
  return b != current;
}

/// Drawer / lifecycle: unpublished read-only edits vs stored baseline / server / dirty / legacy thin sig.
bool computeReadOnlyHasUnpublishedChangesWithBaseline({
  required CreatorStoryV1 draft,
  required String? readOnlyPublishedCoreSig,
  required bool dirty,
  required String? publishedEditReadOnlyBaselineSig,
}) {
  final cur = computeReadOnlyEditBaselineSignature(draft);
  if (_baselineDiff(publishedEditReadOnlyBaselineSig, cur)) return true;
  if (dirty) return true;
  if (draft.hasUnpublishedCoreChanges == true) return true;

  final leg = readOnlyPublishedCoreSig?.trim();
  if (leg != null &&
      leg.isNotEmpty &&
      computeReadOnlyPublishedCoreSignature(draft) != leg) {
    return true;
  }

  return false;
}

/// Drawer: full-learn unpublished — learn layers OR read-only drift.
bool computeFullLearnHasUnpublishedChangesWithBaseline({
  required CreatorStoryV1 draft,
  required String? readOnlyPublishedCoreSig,
  required bool dirty,
  required String? publishedEditReadOnlyBaselineSig,
  required String? publishedEditFullLearnBaselineSig,
}) {
  final curFl = computeFullLearnEditBaselineSignature(draft);
  if (_baselineDiff(publishedEditFullLearnBaselineSig, curFl)) return true;
  return computeReadOnlyHasUnpublishedChangesWithBaseline(
    draft: draft,
    readOnlyPublishedCoreSig: readOnlyPublishedCoreSig,
    dirty: dirty,
    publishedEditReadOnlyBaselineSig: publishedEditReadOnlyBaselineSig,
  );
}
