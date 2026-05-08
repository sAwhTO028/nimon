import 'package:nimon/features/create/story_creator_models.dart';

/// V1 publish validation derived from the existing completion rules in [CreatorStoryV1].
///
/// This is intentionally lightweight and UI-agnostic: it only derives "what's missing"
/// so creator screens can display consistent feedback without inventing new rules.
enum PublishMissingItem {
  title,
  category,
  level,
  description,
  validSentence,
  vocabKanji,
  grammar,
  quiz,
  audio,
}

extension PublishMissingItemLabels on PublishMissingItem {
  String get label => switch (this) {
        PublishMissingItem.title => 'Title',
        PublishMissingItem.category => 'Category',
        PublishMissingItem.level => 'Level',
        PublishMissingItem.description => 'Description',
        PublishMissingItem.validSentence => 'At least one valid sentence',
        PublishMissingItem.vocabKanji => 'Vocabulary / Kanji',
        PublishMissingItem.grammar => 'Grammar',
        PublishMissingItem.quiz => 'Quiz',
        PublishMissingItem.audio => 'Listening / Audio',
      };
}

extension CreatorStoryV1PublishValidation on CreatorStoryV1 {
  List<PublishMissingItem> missingForReadingOnly() {
    final out = <PublishMissingItem>[];
    if (title.trim().isEmpty) out.add(PublishMissingItem.title);
    if (category.trim().isEmpty) out.add(PublishMissingItem.category);
    if (level.trim().isEmpty) out.add(PublishMissingItem.level);
    if (description.trim().isEmpty) out.add(PublishMissingItem.description);
    if (!sentences.any((s) => s.isValidV1)) {
      out.add(PublishMissingItem.validSentence);
    }
    return out;
  }

  List<PublishMissingItem> missingForFullLearn() {
    final out = <PublishMissingItem>[
      ...missingForReadingOnly(),
    ];
    if (!moduleMeetsV1Completion(LearnModuleId.vocabularyKanji)) {
      out.add(PublishMissingItem.vocabKanji);
    }
    if (!moduleMeetsV1Completion(LearnModuleId.grammar)) {
      out.add(PublishMissingItem.grammar);
    }
    if (!moduleMeetsV1Completion(LearnModuleId.quiz)) {
      out.add(PublishMissingItem.quiz);
    }
    if (!moduleMeetsV1Completion(LearnModuleId.audio)) {
      out.add(PublishMissingItem.audio);
    }
    return out;
  }

  /// Learn modules still incomplete by V1 data rules.
  List<LearnModuleId> incompleteLearnModulesV1() {
    final out = <LearnModuleId>[];
    for (final id in LearnModuleId.values) {
      if (!moduleMeetsV1Completion(id)) out.add(id);
    }
    return out;
  }

  /// Compact labels for incomplete learn modules (for warning/reminder UI).
  String incompleteLearnModulesLabel({int maxNames = 3}) {
    final list = incompleteLearnModulesV1().map((e) => e.displayTitle).toList();
    if (list.isEmpty) return '';
    if (list.length <= maxNames) return list.join(' · ');
    return '${list.take(maxNames).join(' · ')} · +${list.length - maxNames} more';
  }

  /// Concise creator-friendly reason string for a blocked publish attempt.
  String blockedReasonReadingOnly() {
    final missing = missingForReadingOnly();
    if (missing.isEmpty) return '';
    return 'Complete ${_joinLabels(missing)} to publish Reading Only.';
  }

  /// Concise creator-friendly reason string for a blocked publish attempt.
  String blockedReasonFullLearn() {
    final missing = missingForFullLearn();
    if (missing.isEmpty) return '';
    return 'Complete ${_joinLabels(missing)} to publish Full Learn.';
  }
}

String _joinLabels(List<PublishMissingItem> items) {
  final labels = items.map((x) => x.label).toList();
  if (labels.length <= 2) return labels.join(' and ');
  return '${labels.sublist(0, labels.length - 1).join(', ')}, and ${labels.last}';
}
