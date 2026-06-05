import 'package:nimon/features/learn/listening_transcript_models.dart';
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';

/// Story sentences for Learn → Listening when the route passes no explicit
/// [ListeningTranscriptLine] list (published snapshot has no timed transcript).
///
/// Delegates to [buildMonoContentFromPublishedCore] so furigana / meanings match
/// Mono reader parsing.
List<ListeningTranscriptLine> listeningTranscriptLinesFromPublishedCore(
  Object? contentRoot, {
  String? learningLanguage,
}) {
  final mono = buildMonoContentFromPublishedCore(
    'listening_fallback',
    null,
    contentRoot,
    learningLanguage: learningLanguage,
  );
  if (mono == null) {
    return const [];
  }
  final out = <ListeningTranscriptLine>[];
  for (final page in mono.pages) {
    for (final sl in page.lines) {
      out.add(
        ListeningTranscriptLine(
          japanese: sl.plainText,
          translationEnglish: sl.explanation?.en,
          translationMyanmar: sl.explanation?.my,
          rubyTokens: sl.tokens.isEmpty ? null : sl.tokens,
          publishedExplanation: sl.explanation,
        ),
      );
    }
  }
  return out;
}
