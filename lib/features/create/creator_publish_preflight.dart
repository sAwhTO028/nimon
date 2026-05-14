import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// Builds portable publish snapshot from the creator aggregate (V1).
StoryPublishData storyPublishDataFromCreator(CreatorStoryV1 d) {
  final mods = <String, String>{};
  for (final e in LearnModuleId.values) {
    mods[e.storageKey] =
        (d.moduleWorkflowStatuses[e] ?? LearnModuleTaskStatus.notStarted)
            .storageKey;
  }

  return StoryPublishData(
    title: d.title,
    description: d.description,
    levelRaw: d.level,
    targetDurationBandKey: d.basics.targetDurationBandKey,
    durationSeconds: null,
    sentences: d.sentences
        .map((s) => <String, Object?>{
              'content': <String, Object?>{
                'japaneseText': s.japaneseText,
                if (s.reading != null) 'reading': s.reading,
              },
            })
        .toList(),
    vocabEntries: d.vocabularyKanji.entries
        .map(
          (e) => <String, Object?>{
            'content': <String, Object?>{
              'termJapanese': e.termJapanese,
              'type': e.type.storageKey,
              if (e.reading != null) 'reading': e.reading,
              if (e.glosses != null)
                'glosses': <String, Object?>{
                  if (e.glosses!.my != null) 'my': e.glosses!.my,
                  if (e.glosses!.en != null) 'en': e.glosses!.en,
                },
            },
          },
        )
        .toList(),
    grammarEntries: d.grammar.entries
        .map(
          (g) => <String, Object?>{
            'content': <String, Object?>{
              'headline': g.headline,
            },
          },
        )
        .toList(),
    quizEntries: d.quiz.entries
        .map(
          (q) => <String, Object?>{
            'content': <String, Object?>{
              'category': q.category.storageKey,
              'prompt': q.prompt,
              'options': q.options,
              'correctIndex': q.correctIndex,
            },
          },
        )
        .toList(),
    moduleWorkflowStatuses: mods,
  );
}
