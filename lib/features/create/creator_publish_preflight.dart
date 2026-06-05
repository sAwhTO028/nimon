import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_prompt_source_note.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// Result of the same preflight path used by Full Learn Publish in the drawer.
class FullLearnPublishPreflightResult {
  const FullLearnPublishPreflightResult({
    required this.normalizedDraft,
    required this.publishData,
    required this.validation,
    required this.resolvedMode,
  });

  final CreatorStoryV1 normalizedDraft;
  final StoryPublishData publishData;
  final ValidationResult validation;
  final HtmlPromptMode resolvedMode;
}

const _legacyQuizRangeKey = 'learn.count.quiz.range';

/// Drops legacy JLPT quiz band issues — Full Learn publish uses [HtmlGeneratorLimits] only.
List<ValidationIssue> withoutLegacyFullLearnQuizRangeIssues(
  List<ValidationIssue> issues,
) {
  return issues
      .where(
        (i) => i.messageKey != _legacyQuizRangeKey && i.code != _legacyQuizRangeKey,
      )
      .toList();
}

ValidationResult _withoutLegacyFullLearnQuizRange(ValidationResult r) {
  final filtered = withoutLegacyFullLearnQuizRangeIssues(r.issues);
  if (filtered.length == r.issues.length) return r;
  final blocking =
      filtered.any((i) => i.severity == ValidationSeverity.blocking);
  return ValidationResult(ok: !blocking, issues: filtered);
}

/// Normalizes import prompt mode, builds [StoryPublishData], runs [validateStoryPublishData].
///
/// This is the single Full Learn publish gate (no legacy JLPT quiz range tables).
FullLearnPublishPreflightResult runFullLearnPublishPreflight(CreatorStoryV1 raw) {
  final normalized = withBackfilledImportPromptSourceNote(raw);
  final data = storyPublishDataFromCreator(normalized);
  final validation = _withoutLegacyFullLearnQuizRange(
    validateStoryPublishData(
      data,
      ValidationMode.fullLearnPublish,
    ),
  );
  final mode = resolveHtmlPromptModeFromSourceNote(data.promptSourceNote);
  return FullLearnPublishPreflightResult(
    normalizedDraft: normalized,
    publishData: data,
    validation: validation,
    resolvedMode: mode,
  );
}

/// Builds portable publish snapshot from the creator aggregate (V1).
StoryPublishData storyPublishDataFromCreator(CreatorStoryV1 d) {
  final draft = withBackfilledImportPromptSourceNote(d);
  final mods = <String, String>{};
  for (final e in LearnModuleId.values) {
    mods[e.storageKey] =
        (draft.moduleWorkflowStatuses[e] ?? LearnModuleTaskStatus.notStarted)
            .storageKey;
  }

  return StoryPublishData(
    title: draft.title,
    description: draft.description,
    levelRaw: draft.level,
    targetDurationBandKey: draft.basics.targetDurationBandKey,
    durationSeconds: null,
    learningLanguage: draft.basics.learningLanguage,
    // Must match [resolveHtmlPromptModeForDraft] / creator readiness (effective note).
    promptSourceNote: effectiveCreatorDraftPromptSourceNote(draft),
    sentences: draft.sentences
        .map((s) => <String, Object?>{
              'content': <String, Object?>{
                'japaneseText': s.japaneseText,
                if (s.reading != null) 'reading': s.reading,
              },
            })
        .toList(),
    vocabEntries: draft.vocabularyKanji.entries
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
    grammarEntries: draft.grammar.entries
        .map(
          (g) => <String, Object?>{
            'content': <String, Object?>{
              'headline': g.headline,
            },
          },
        )
        .toList(),
    quizEntries: draft.quiz.entries
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
