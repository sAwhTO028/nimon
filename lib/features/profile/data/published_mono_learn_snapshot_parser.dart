import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/remote_story_draft_learn_layers_wire.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// Parsed `published_monos.content.learn` from full-learn publish (M4b1).
///
/// Built from the same JSON shapes as draft sync (`remote_story_draft_learn_layers_wire.dart`).
class LearnPublishedSnapshot {
  const LearnPublishedSnapshot({
    required this.schemaVersion,
    required this.vocabularyKanjiEntries,
    required this.grammarEntries,
    required this.quizEntries,
    this.storyAudio,
  });

  /// Currently **1** from backend; callers should tolerate unknown future versions via [learnPublishedSnapshotFromContent] returning null.
  final int schemaVersion;
  final List<VocabularyKanjiEntryDto> vocabularyKanjiEntries;
  final List<GrammarEntryDto> grammarEntries;
  final List<QuizEntryDto> quizEntries;
  final StoryAudioDto? storyAudio;

  bool get hasAnyLearnData =>
      vocabularyKanjiEntries.isNotEmpty ||
      grammarEntries.isNotEmpty ||
      quizEntries.isNotEmpty ||
      storyAudio != null;
}

Map<String, Object?>? _stringKeyMap(Object? raw) {
  if (raw is! Map) return null;
  return {for (final e in raw.entries) e.key.toString(): e.value};
}

int? _schemaVersionInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  return null;
}

/// Extracts `learn` from [PublishedMonoDetailDto.content] (same shape as public mono detail).
LearnPublishedSnapshot? learnPublishedSnapshotFromPublishedMonoDetail(
  PublishedMonoDetailDto dto,
) =>
    learnPublishedSnapshotFromContent(dto.content);

/// Parses `content.learn` from PublishedMono JSON.
///
/// Returns **null** when:
/// - [content] is not a [Map], or
/// - `content['learn']` is missing or not a [Map], or
/// - `schemaVersion` is present and **not** `1` (future versions unsupported until parser update).
///
/// When `schemaVersion` is **omitted**, it is treated as **1** (tolerant — matches M4b1 backend).
///
/// Does not throw on malformed public payloads; bad rows are skipped.
LearnPublishedSnapshot? learnPublishedSnapshotFromContent(Object? content) {
  final root = _stringKeyMap(content);
  if (root == null) return null;

  final learn = _stringKeyMap(root['learn']);
  if (learn == null) return null;

  final svRaw = learn['schemaVersion'];
  final svParsed = _schemaVersionInt(svRaw);
  if (svParsed != null && svParsed != 1) {
    return null;
  }
  const effectiveVersion = 1;

  final vocabLayer = _stringKeyMap(learn['vocabularyKanji']);
  final grammarLayer = _stringKeyMap(learn['grammar']);
  final quizLayer = _stringKeyMap(learn['quiz']);
  final audioLayer = _stringKeyMap(learn['audio']);

  final vocabularyKanjiEntries = _mapVocabList(vocabLayer?['entries']);
  final grammarEntries = _mapGrammarList(grammarLayer?['entries']);
  final quizEntries = _mapQuizList(quizLayer?['entries']);
  final storyAudio = _parseStoryAudio(audioLayer?['storyAudio']);

  return LearnPublishedSnapshot(
    schemaVersion: effectiveVersion,
    vocabularyKanjiEntries: vocabularyKanjiEntries,
    grammarEntries: grammarEntries,
    quizEntries: quizEntries,
    storyAudio: storyAudio,
  );
}

List<VocabularyKanjiEntryDto> _mapVocabList(Object? raw) {
  if (raw is! List) return const [];
  final out = <VocabularyKanjiEntryDto>[];
  for (final x in raw) {
    final m = _stringKeyMap(x);
    if (m == null) continue;
    out.add(vocabularyKanjiEntryDtoFromWireJson(m));
  }
  return out;
}

List<GrammarEntryDto> _mapGrammarList(Object? raw) {
  if (raw is! List) return const [];
  final out = <GrammarEntryDto>[];
  for (final x in raw) {
    final m = _stringKeyMap(x);
    if (m == null) continue;
    out.add(grammarEntryDtoFromWireJson(m));
  }
  return out;
}

List<QuizEntryDto> _mapQuizList(Object? raw) {
  if (raw is! List) return const [];
  final out = <QuizEntryDto>[];
  for (final x in raw) {
    final m = _stringKeyMap(x);
    if (m == null) continue;
    out.add(quizEntryDtoFromWireJson(m));
  }
  return out;
}

StoryAudioDto? _parseStoryAudio(Object? raw) {
  if (raw == null) return null;
  final m = _stringKeyMap(raw);
  if (m == null) return null;
  return storyAudioDtoFromWireJson(m);
}
