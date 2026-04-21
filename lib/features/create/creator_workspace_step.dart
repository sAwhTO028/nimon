import 'package:nimon/features/create/story_creator_models.dart';

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
  switch (route) {
    case '/create/story/basics':
      return CreatorWorkspaceStep.storyBasics;
    case '/create/story/sentences':
      return CreatorWorkspaceStep.storySentences;
    case '/create/story/learn/vocabulary':
      return CreatorWorkspaceStep.vocabulary;
    case '/create/story/learn/grammar':
      return CreatorWorkspaceStep.grammar;
    case '/create/story/learn/quiz':
      return CreatorWorkspaceStep.quiz;
    case '/create/story/learn/audio':
      return CreatorWorkspaceStep.listeningPronunciation;
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
