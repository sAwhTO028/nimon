/// Cheap 0–100 completion estimate (mirrors `StoryDraftsService.listSummaryCompletionPercent`):
/// 35% basics (5 fields) + 25% sentence volume (full at ≥5) + 40% learn modules (4×10/5).
int computeCheapDraftSummaryCompletionPercent({
  required String title,
  required String category,
  required String level,
  required String description,
  String? targetDurationBandKey,
  required int sentenceCount,
  required Map<String, String> moduleWorkflowStatuses,
}) {
  final slots = [
    title.trim(),
    category.trim(),
    level.trim(),
    description.trim(),
    targetDurationBandKey?.trim() ?? '',
  ];
  final filledBasics = slots.where((s) => s.isNotEmpty).length;
  final basicsScore = (filledBasics / 5) * 35;
  final sentenceScore = (sentenceCount / 5).clamp(0.0, 1.0) * 25;
  const keys = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'];
  var modulePoints = 0.0;
  for (final k in keys) {
    final st = (moduleWorkflowStatuses[k] ?? 'not_started').toLowerCase();
    if (st == 'completed') {
      modulePoints += 10;
    } else if (st == 'in_progress') {
      modulePoints += 5;
    }
  }
  final raw = basicsScore + sentenceScore + modulePoints;
  return raw.clamp(0, 100).round();
}

bool learnModeEnabledFromModuleMap(Map<String, String> m) {
  for (final v in m.values) {
    if (v.toLowerCase() != 'not_started') {
      return true;
    }
  }
  return false;
}

String? lastEditingModuleHeuristic(Map<String, String> m) {
  const order = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'];
  for (final k in order) {
    if ((m[k] ?? 'not_started').toLowerCase() == 'in_progress') {
      return k;
    }
  }
  return null;
}

Map<String, String> mergeWithDefaultModuleStatuses(
    Map<String, String> partial) {
  const defaults = <String, String>{
    'vocabulary_kanji': 'not_started',
    'grammar': 'not_started',
    'quiz': 'not_started',
    'audio': 'not_started',
  };
  return {...defaults, ...partial};
}
