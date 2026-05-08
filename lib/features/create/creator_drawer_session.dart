import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/creator_navigation_debug.dart';
import 'package:nimon/features/create/creator_workspace_step.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// High-level creator surface for session + drawer (V1).
///
/// When [CreatorModule.vocabulary] (or other learn embed) is active on the
/// Story sentences host, vocabulary actions must not reset the UI back to the
/// plaintext sentence list unless the user leaves that host or chooses
/// "Story sentences" explicitly.
enum CreatorModule {
  storyHub,
  storyBasics,
  storySentences,
  vocabulary,
  grammar,
  quiz,
  listeningPronunciation,
  review,
}

/// In-memory route + “visited learn editor” tracking so the creator progress
/// drawer can reflect the active page even when it is only hosted on Sentences.
class CreatorDrawerSessionState {
  const CreatorDrawerSessionState({
    this.matchedPath = '/create/story',
    this.learnModulesVisited = const <LearnModuleId>{},
    this.sentencesMainStep = CreatorWorkspaceStep.storySentences,
    this.activeModule = CreatorModule.storyHub,
    this.learnModeEnabled = false,
  });

  /// Canonical `/create/story/...` path (prefer [Uri.path] from GoRouter).
  final String matchedPath;

  /// Learn module editors the user has opened at least once this session.
  final Set<LearnModuleId> learnModulesVisited;

  /// Embedded main panel when [matchedPath] is Story sentences (drawer-driven).
  final CreatorWorkspaceStep sentencesMainStep;

  /// Resolved creator surface (drawer + embedded host).
  final CreatorModule activeModule;

  /// When false: Read Only flow; Learn module rows are inactive and user should not
  /// remain on a Learn surface. When true: Full Learn flow; Learn editors are available.
  final bool learnModeEnabled;

  CreatorDrawerSessionState copyWith({
    String? matchedPath,
    Set<LearnModuleId>? learnModulesVisited,
    CreatorWorkspaceStep? sentencesMainStep,
    CreatorModule? activeModule,
    bool? learnModeEnabled,
  }) {
    return CreatorDrawerSessionState(
      matchedPath: matchedPath ?? this.matchedPath,
      learnModulesVisited: learnModulesVisited ?? this.learnModulesVisited,
      sentencesMainStep: sentencesMainStep ?? this.sentencesMainStep,
      activeModule: activeModule ?? this.activeModule,
      learnModeEnabled: learnModeEnabled ?? this.learnModeEnabled,
    );
  }
}

class CreatorDrawerSessionNotifier
    extends StateNotifier<CreatorDrawerSessionState> {
  CreatorDrawerSessionNotifier() : super(const CreatorDrawerSessionState());

  static final _setEq = const SetEquality<LearnModuleId>();

  /// Single source of truth for Learn mode (Read Only vs Full Learn). Does not navigate.
  void setLearnMode(bool enabled) {
    if (state.learnModeEnabled == enabled) return;
    state = state.copyWith(learnModeEnabled: enabled);
  }

  /// Reset *ephemeral* UI session tracking while preserving persistent choices.
  ///
  /// Persistent examples: Learn mode selection.
  void resetEphemeralUiState() {
    final preserveLearnMode = state.learnModeEnabled;
    state = CreatorDrawerSessionState(learnModeEnabled: preserveLearnMode);
  }

  /// Prefer the real navigation [Uri.path]; [matchedPath] alone can be a
  /// subtree location while the user is still on `/create/story/sentences`.
  static String _canonicalCreateStoryPath(
      String matchedPath, Uri? locationUri) {
    final fromUri = locationUri?.path;
    if (fromUri != null && fromUri.isNotEmpty && fromUri.startsWith('/')) {
      return fromUri;
    }
    final raw = matchedPath.trim();
    if (raw.isEmpty) return '/create/story';
    final withSlash = raw.startsWith('/') ? raw : '/$raw';
    if (withSlash == '/sentences') {
      return '/create/story/sentences';
    }
    return withSlash;
  }

  static CreatorModule _moduleFromSentencesWorkspaceStep(
      CreatorWorkspaceStep step) {
    return switch (step) {
      CreatorWorkspaceStep.vocabulary => CreatorModule.vocabulary,
      CreatorWorkspaceStep.grammar => CreatorModule.grammar,
      CreatorWorkspaceStep.quiz => CreatorModule.quiz,
      CreatorWorkspaceStep.listeningPronunciation =>
        CreatorModule.listeningPronunciation,
      CreatorWorkspaceStep.storySentences => CreatorModule.storySentences,
      CreatorWorkspaceStep.storyBasics => CreatorModule.storyBasics,
    };
  }

  static CreatorModule _activeModuleForPath(
    String path,
    Map<String, String> query,
    CreatorWorkspaceStep embedStep,
  ) {
    if (path == '/create/story' || path == '/create/story/') {
      return CreatorModule.storyHub;
    }
    if (path.startsWith('/create/story/basics')) {
      return CreatorModule.storyBasics;
    }
    if (isStorySentencesCreatorPath(path)) {
      final fromPanel = creatorWorkspaceStepForSentencesPanel(query['panel']);
      final step = fromPanel ?? embedStep;
      return _moduleFromSentencesWorkspaceStep(step);
    }
    return CreatorModule.storyHub;
  }

  /// Keeps [sentencesMainStep] when the user is still on the sentences host or on a
  /// legacy `/create/story/learn/*` editor path (redirect / sync flicker must not wipe
  /// the embedded Vocabulary / Grammar / Quiz / Audio workspace).
  static bool _preserveSentencesWorkspaceStep(String path) {
    if (isStorySentencesCreatorPath(path)) return true;
    return false;
  }

  /// Updates path and records a learn-module visit when [path] targets an editor.
  ///
  /// Pass [locationUri] (e.g. [GoRouterState.uri]) so `?panel=vocabulary` and the
  /// real path are honored even when [matchedPath] is a partial sub-location.
  void reportRoute(String matchedPath, {Uri? locationUri}) {
    final path = _canonicalCreateStoryPath(matchedPath, locationUri);
    final uriStr = locationUri?.toString() ?? '';
    final panelQ = locationUri?.queryParameters['panel'];
    creatorNavDebug(
      'reportRoute',
      'ENTER matchedPathIn=$matchedPath locationUri=$uriStr canonical=$path panel=$panelQ',
    );

    if (!path.startsWith('/create/story')) {
      creatorNavDebug('reportRoute', 'SKIP not under /create/story');
      return;
    }

    final query = locationUri?.queryParameters ?? const <String, String>{};

    LearnModuleId? opened;
    if (path.contains('/learn/vocabulary')) {
      opened = LearnModuleId.vocabularyKanji;
    } else if (path.contains('/learn/grammar')) {
      opened = LearnModuleId.grammar;
    } else if (path.contains('/learn/quiz')) {
      opened = LearnModuleId.quiz;
    } else if (path.contains('/learn/audio')) {
      opened = LearnModuleId.audio;
    }

    final nextVisited = opened == null
        ? state.learnModulesVisited
        : {...state.learnModulesVisited, opened};

    final onSentencesHost = isStorySentencesCreatorPath(path);
    final fromPanel = onSentencesHost
        ? creatorWorkspaceStepForSentencesPanel(query['panel'])
        : null;

    final beforeStep = state.sentencesMainStep;
    final beforeMod = state.activeModule;
    final beforeSentenceVisible =
        beforeStep == CreatorWorkspaceStep.storySentences;

    final CreatorWorkspaceStep nextSentencesMainStep;
    if (onSentencesHost) {
      // V1: `?panel=` on the sentences host (or absence → main story sentences) is canonical.
      nextSentencesMainStep = fromPanel ?? CreatorWorkspaceStep.storySentences;
    } else if (_preserveSentencesWorkspaceStep(path)) {
      // Legacy learn deep paths / redirect flicker: keep last embed until path stabilizes.
      nextSentencesMainStep = fromPanel ?? state.sentencesMainStep;
    } else {
      nextSentencesMainStep = CreatorWorkspaceStep.storySentences;
    }

    final nextActiveModule =
        _activeModuleForPath(path, query, nextSentencesMainStep);
    final afterSentenceVisible =
        nextSentencesMainStep == CreatorWorkspaceStep.storySentences;
    final sentenceVisibleChanged =
        beforeSentenceVisible != afterSentenceVisible;

    creatorNavDebug(
      'reportRoute',
      'COMPUTE preserve=${_preserveSentencesWorkspaceStep(path)} onSentencesHost=$onSentencesHost '
          'fromPanel=$fromPanel | before step=$beforeStep mod=$beforeMod sentenceListVisible=$beforeSentenceVisible '
          '| next step=$nextSentencesMainStep mod=$nextActiveModule sentenceListVisible=$afterSentenceVisible '
          '| visibleSentenceWorkspaceChanged=$sentenceVisibleChanged',
    );

    if (state.matchedPath == path &&
        _setEq.equals(state.learnModulesVisited, nextVisited) &&
        state.sentencesMainStep == nextSentencesMainStep &&
        state.activeModule == nextActiveModule) {
      creatorNavDebug('reportRoute', 'NOOP (state already matched)');
      return;
    }

    state = state.copyWith(
      matchedPath: path,
      learnModulesVisited: nextVisited,
      sentencesMainStep: nextSentencesMainStep,
      activeModule: nextActiveModule,
    );
    creatorNavDebug(
      'reportRoute',
      'APPLIED matchedPath=${state.matchedPath} step=${state.sentencesMainStep} mod=${state.activeModule}',
    );
  }

  /// Switches embedded learn / sentences panel on the Story sentences host screen.
  ///
  /// Only call from the Story sentences creator screen. If route sync lags, [matchedPath]
  /// is normalized to `/create/story/sentences` so drawer state stays consistent.
  void setSentencesMainStep(CreatorWorkspaceStep next) {
    final beforeStep = state.sentencesMainStep;
    final beforeMod = state.activeModule;
    final beforeVis = beforeStep == CreatorWorkspaceStep.storySentences;
    if (state.sentencesMainStep == next) {
      creatorNavDebug(
        'setSentencesMainStep',
        'NOOP next=$next (already) mod=$beforeMod sentenceListVisible=$beforeVis',
      );
      return;
    }

    final prev = state.sentencesMainStep;
    final prevModule = learnModuleIdForWorkspaceLearnStep(prev);
    final nextVisited = prevModule == null
        ? state.learnModulesVisited
        : {...state.learnModulesVisited, prevModule};

    final path = isStorySentencesCreatorPath(state.matchedPath)
        ? state.matchedPath
        : '/create/story/sentences';

    final nextModule = isStorySentencesCreatorPath(path)
        ? _moduleFromSentencesWorkspaceStep(next)
        : state.activeModule;

    final afterVis = next == CreatorWorkspaceStep.storySentences;
    creatorNavDebug(
      'setSentencesMainStep',
      'APPLY $beforeStep->$next mod $beforeMod->$nextModule '
          'sentenceListVisible $beforeVis->$afterVis matchedPath=$path',
    );

    state = state.copyWith(
      matchedPath: path,
      sentencesMainStep: next,
      learnModulesVisited: nextVisited,
      activeModule: nextModule,
    );
    creatorNavDebug(
      'setSentencesMainStep',
      'AFTER step=${state.sentencesMainStep} mod=${state.activeModule}',
    );
  }

  /// After learn-module edits on the Story sentences host, restore the embedded panel
  /// if session drifted back to [CreatorWorkspaceStep.storySentences] by mistake.
  ///
  /// Also re-aligns [activeModule] when [sentencesMainStep] is already correct but
  /// [activeModule] drifted (drawer / route sync), so Vocabulary stays "locked" until
  /// the user explicitly leaves.
  ///
  /// Does not navigate; no-op when not on `/create/story/sentences` or when [step] is
  /// not a learn embed.
  void retainSentencesHostEmbeddedStep(
    CreatorWorkspaceStep step, {
    String debugAction = '',
  }) {
    if (!isStorySentencesCreatorPath(state.matchedPath)) return;
    if (learnModuleIdForWorkspaceLearnStep(step) == null) return;

    void debugAfter(String phase) {
      if (debugAction.isEmpty) return;
      final s = state;
      creatorNavDebug(
        'retain_embed',
        '[vocab_page_persist] $phase action=$debugAction | '
            'matchedPath=${s.matchedPath} | sentencesMainStep=${s.sentencesMainStep} | '
            'activeModule=${s.activeModule} | '
            'sentenceListVisible=${s.sentencesMainStep == CreatorWorkspaceStep.storySentences}',
      );
    }

    if (debugAction.isNotEmpty) {
      creatorNavDebug(
        'retain_embed',
        '[vocab_page_persist] BEFORE action=$debugAction | '
            'matchedPath=${state.matchedPath} | sentencesMainStep=${state.sentencesMainStep} | '
            'activeModule=${state.activeModule} | '
            'sentenceListVisible=${state.sentencesMainStep == CreatorWorkspaceStep.storySentences}',
      );
    }

    final expectedModule = _moduleFromSentencesWorkspaceStep(step);

    if (state.sentencesMainStep != step) {
      setSentencesMainStep(step);
      debugAfter('AFTER_setStep');
      return;
    }

    if (state.activeModule != expectedModule) {
      state = state.copyWith(activeModule: expectedModule);
      debugAfter('AFTER_fixActiveModule');
    } else {
      debugAfter('AFTER_noop');
    }
  }
}

final creatorDrawerSessionProvider = StateNotifierProvider<
    CreatorDrawerSessionNotifier, CreatorDrawerSessionState>(
  (ref) => CreatorDrawerSessionNotifier(),
);
