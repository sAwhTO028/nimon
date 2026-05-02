import 'package:nimon/features/create/story_creator_models.dart';

/// Pushes a creator progress route with [draftId] merged into the query.
///
/// Used by embedded module editors' drawers so `?panel=…` is preserved.
String createStoryProgressRouteWithDraftId(String route, String draftId) {
  final d = draftId.trim();
  if (d.isEmpty) return route;
  var r = route.trim();
  if (r.isEmpty) return route;
  if (!r.startsWith('/')) r = '/$r';
  if (r.startsWith('/create/story/basics')) {
    if (r.contains('draftId=')) return r;
    return r.contains('?') ? '$r&draftId=$d' : '$r?draftId=$d';
  }
  if (r.startsWith('/create/story/sentences')) {
    final u = Uri.parse('https://nimon.app$r');
    final m = Map<String, String>.from(u.queryParameters);
    m['draftId'] = d;
    return Uri(
      path: '/create/story/sentences',
      queryParameters: m,
    ).toString();
  }
  if (r.contains('draftId=')) return r;
  return r.contains('?') ? '$r&draftId=$d' : '$r?draftId=$d';
}

/// V1 creator workspace step: drives embedded main content on Story sentences
/// and progress chips when the route is still `/create/story/sentences`.
enum CreatorWorkspaceStep {
  storyBasics,
  storySentences,
  vocabulary,
  grammar,
  quiz,
  listeningPronunciation,
}

/// Drawer row routes for `/create/story/...` creator flow.
CreatorWorkspaceStep? creatorWorkspaceStepForDrawerRoute(String route) {
  var r = route.trim();
  if (r.isEmpty) return null;
  if (!r.startsWith('/')) r = '/$r';
  if (r.startsWith('/create/story/sentences')) {
    final u = Uri.parse('https://nimon.app$r');
    return creatorWorkspaceStepForSentencesPanel(u.queryParameters['panel']) ??
        CreatorWorkspaceStep.storySentences;
  }
  final pathOnly = r.split('?').first;
  switch (pathOnly) {
    case '/create/story/basics':
      return CreatorWorkspaceStep.storyBasics;
    default:
      return null;
  }
}

LearnModuleId? learnModuleIdForWorkspaceLearnStep(CreatorWorkspaceStep step) {
  return switch (step) {
    CreatorWorkspaceStep.vocabulary => LearnModuleId.vocabularyKanji,
    CreatorWorkspaceStep.grammar => LearnModuleId.grammar,
    CreatorWorkspaceStep.quiz => LearnModuleId.quiz,
    CreatorWorkspaceStep.listeningPronunciation => LearnModuleId.audio,
    _ => null,
  };
}

bool isStorySentencesCreatorPath(String matchedPath) {
  final uri = Uri.parse(
    matchedPath.startsWith('/') ? matchedPath : '/$matchedPath',
  );
  final s = uri.pathSegments;
  return s.length == 3 &&
      s[0] == 'create' &&
      s[1] == 'story' &&
      s[2] == 'sentences';
}

/// Maps `?panel=` on `/create/story/sentences` to the embedded workspace step.
CreatorWorkspaceStep? creatorWorkspaceStepForSentencesPanel(String? panelRaw) {
  final panel = (panelRaw ?? '').trim();
  return switch (panel) {
    'vocabulary' => CreatorWorkspaceStep.vocabulary,
    'grammar' => CreatorWorkspaceStep.grammar,
    'quiz' => CreatorWorkspaceStep.quiz,
    'listening' => CreatorWorkspaceStep.listeningPronunciation,
    _ => null,
  };
}
