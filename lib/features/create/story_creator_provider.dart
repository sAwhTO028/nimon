import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/current_user_id_provider.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/creator_published_edit_baseline.dart';
import 'package:nimon/features/create/creator_read_only_publish_tracking.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorDraftResumeMeta, CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_public_audio_url.dart';
import 'package:uuid/uuid.dart';

StoryDraftRemotePublishIntent _remotePublishIntentForSaveReason(String reason) {
  switch (reason) {
    case 'publish_reading_only':
      return StoryDraftRemotePublishIntent.readOnly;
    case 'publish_full_learn':
      return StoryDraftRemotePublishIntent.fullLearn;
    default:
      return StoryDraftRemotePublishIntent.none;
  }
}

List<VocabularyExamplePair> _normalizeVocabExamplePairs(
  List<VocabularyExamplePair> raw,
) {
  final out = <VocabularyExamplePair>[];
  for (final p in raw) {
    if (out.length >= 3) break;
    final s = p.sourceExample.trim();
    final e = p.englishExample.trim();
    if (s.isEmpty && e.isEmpty) continue;
    out.add(VocabularyExamplePair(sourceExample: s, englishExample: e));
  }
  return out;
}

(String?, LocalizedMeanings?) _legacyMergedExampleFields(
  List<VocabularyExamplePair> pairs,
) {
  if (pairs.isEmpty) return (null, null);
  final jpParts = <String>[];
  final enParts = <String>[];
  for (final p in pairs) {
    if (p.sourceExample.isNotEmpty) jpParts.add(p.sourceExample);
    if (p.englishExample.isNotEmpty) enParts.add(p.englishExample);
  }
  final jp = jpParts.join('\n\n');
  final en = enParts.join('\n\n');
  return (
    jp.isEmpty ? null : jp,
    en.isEmpty ? null : LocalizedMeanings(en: en),
  );
}

enum CreatorDraftSaveStatus { idle, saving, saved, failed }

class StoryCreatorDraftState {
  const StoryCreatorDraftState({
    required this.draft,
    required this.dirty,
    required this.saveStatus,
    required this.lastSavedAt,
    required this.lastSaveError,
    required this.readOnlyPublishedCoreSig,
    required this.publishedEditReadOnlyBaselineSig,
    required this.publishedEditFullLearnBaselineSig,
  });

  final CreatorStoryV1 draft;
  final bool dirty;
  final CreatorDraftSaveStatus saveStatus;
  final DateTime? lastSavedAt;
  final String? lastSaveError;

  /// Stored signature of the last successfully **Read Only** published story core.
  final String? readOnlyPublishedCoreSig;

  /// Last published **read-only** snapshot (v2: basics + sentences detail). Updated on publish only.
  final String? publishedEditReadOnlyBaselineSig;

  /// Last published **full learn** snapshot. Updated on full-learn publish; cleared for RO-only.
  final String? publishedEditFullLearnBaselineSig;

  factory StoryCreatorDraftState.initial({required String creatorOwnerId}) =>
      StoryCreatorDraftState(
        draft: CreatorStoryV1.empty(creatorOwnerId: creatorOwnerId),
        dirty: false,
        saveStatus: CreatorDraftSaveStatus.idle,
        lastSavedAt: null,
        lastSaveError: null,
        readOnlyPublishedCoreSig: null,
        publishedEditReadOnlyBaselineSig: null,
        publishedEditFullLearnBaselineSig: null,
      );

  StoryCreatorDraftState copyWith({
    CreatorStoryV1? draft,
    bool? dirty,
    CreatorDraftSaveStatus? saveStatus,
    DateTime? lastSavedAt,
    String? lastSaveError,
    bool clearLastSaveError = false,
    String? readOnlyPublishedCoreSig,
    bool clearReadOnlyPublishedCoreSig = false,
    String? publishedEditReadOnlyBaselineSig,
    String? publishedEditFullLearnBaselineSig,
    bool clearPublishedEditBaselines = false,
  }) {
    return StoryCreatorDraftState(
      draft: draft ?? this.draft,
      dirty: dirty ?? this.dirty,
      saveStatus: saveStatus ?? this.saveStatus,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      lastSaveError:
          clearLastSaveError ? null : (lastSaveError ?? this.lastSaveError),
      readOnlyPublishedCoreSig: clearReadOnlyPublishedCoreSig
          ? null
          : (readOnlyPublishedCoreSig ?? this.readOnlyPublishedCoreSig),
      publishedEditReadOnlyBaselineSig: clearPublishedEditBaselines
          ? null
          : (publishedEditReadOnlyBaselineSig ??
              this.publishedEditReadOnlyBaselineSig),
      publishedEditFullLearnBaselineSig: clearPublishedEditBaselines
          ? null
          : (publishedEditFullLearnBaselineSig ??
              this.publishedEditFullLearnBaselineSig),
    );
  }
}

class StoryCreatorDraftNotifier extends StateNotifier<StoryCreatorDraftState> {
  StoryCreatorDraftNotifier(
    this._drafts,
    this._devOwnerId, {
    void Function()? onProfileProcessingListChanged,
  })  : _onProfileProcessingListChanged = onProfileProcessingListChanged,
        super(StoryCreatorDraftState.initial(creatorOwnerId: _devOwnerId));

  final StoryDraftRepository _drafts;
  final void Function()? _onProfileProcessingListChanged;

  void _bumpProfileProcessingListRefresh() {
    _onProfileProcessingListChanged?.call();
  }

  /// Development (later: authenticated) user id for [StoryBasics.creatorOwnerId].
  final String _devOwnerId;

  bool _hydrated = false;
  Timer? _persistDebounce;

  bool get hydratedFromDisk => _hydrated;

  CreatorStoryV1 get draft => state.draft;

  String _effectiveCreatorOwnerId() {
    final v = state.draft.basics.creatorOwnerId.trim();
    return v.isEmpty ? _devOwnerId : v;
  }

  /// Explicitly load a specific local draft (no implicit resume in the Add/Create entry point).
  ///
  /// When [forceReloadFromDisk] is false (default), if [draftId] is already the active in-memory
  /// draft id, returns immediately **without** reading storage — so unsaved edits are not wiped
  /// by redundant reloads (e.g. route reconcile after popping Story Basics).
  ///
  /// Resume / Processing / Published reopen passes [forceReloadFromDisk: true] so the session
  /// is rehydrated from disk for that entry flow.
  Future<void> loadDraftById(
    String draftId, {
    bool forceReloadFromDisk = false,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    if (!forceReloadFromDisk && state.draft.id.trim() == id) {
      return;
    }
    var loaded = await _drafts.loadDraft(id);
    _hydrated = true;
    if (loaded == null) return;
    // Align stored owner with current dev identity (fixes legacy `dev_user_1` etc.).
    final needsOwnerBackfill =
        loaded.basics.creatorOwnerId.trim() != _devOwnerId.trim();
    if (needsOwnerBackfill) {
      if (kDebugMode) {
        debugPrint(
          '[creator_draft] owner_backfill draftId=$id '
          'remote=${RemoteBackendConfig.useRemoteDrafts} '
          'was="${loaded.basics.creatorOwnerId}" '
          'expected_dev_owner="${RemoteBackendConfig.devOwnerId}" '
          'notifier_dev=$_devOwnerId',
        );
      }
      loaded = loaded.copyWith(
        basics: loaded.basics.copyWith(creatorOwnerId: _devOwnerId),
      );
    }
    state = state.copyWith(
      draft: loaded,
      dirty: false,
      saveStatus: CreatorDraftSaveStatus.saved,
      lastSavedAt: await _drafts.savedAt(id),
      clearLastSaveError: true,
    );
    unawaited(_hydrateReadOnlyPublishSig(id));
    unawaited(_hydratePublishedEditBaselines(id));
    if (needsOwnerBackfill) {
      await persistLocalNow(reason: 'owner_backfill');
    }
  }

  Future<void> _hydrateReadOnlyPublishSig(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    final sig = await loadReadOnlyPublishedCoreSignature(id);
    if (state.draft.id != id) return;
    state = state.copyWith(readOnlyPublishedCoreSig: sig);
  }

  Future<void> _hydratePublishedEditBaselines(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    var ro = await loadPublishedEditReadOnlyBaseline(id);
    var fl = await loadPublishedEditFullLearnBaseline(id);
    if (state.draft.id.trim() != id) return;
    final draft = state.draft;
    final linked = draft.publishedMonoId?.trim().isNotEmpty == true ||
        draft.publishState != StoryPublishState.draft;
    if (!linked) {
      state = state.copyWith(clearPublishedEditBaselines: true);
      return;
    }

    final clean = draft.hasUnpublishedCoreChanges != true;
    if (ro == null && clean) {
      ro = computeReadOnlyEditBaselineSignature(draft);
      await savePublishedEditReadOnlyBaseline(id, ro);
    }
    if (draft.publishState == StoryPublishState.fullLearnPublished &&
        fl == null &&
        clean) {
      fl = computeFullLearnEditBaselineSignature(draft);
      await savePublishedEditFullLearnBaseline(id, fl);
    }

    if (state.draft.id.trim() != id) return;
    state = state.copyWith(
      publishedEditReadOnlyBaselineSig: ro,
      publishedEditFullLearnBaselineSig: fl,
    );
  }

  Future<void> _persistPublishedEditBaselinesAfterSuccessfulPublish() async {
    final id = state.draft.id.trim();
    if (id.isEmpty) return;
    final d = state.draft;
    final ro = computeReadOnlyEditBaselineSignature(d);
    await savePublishedEditReadOnlyBaseline(id, ro);
    String? flSig;
    if (d.publishState == StoryPublishState.fullLearnPublished) {
      flSig = computeFullLearnEditBaselineSignature(d);
      await savePublishedEditFullLearnBaseline(id, flSig);
    } else {
      await clearPublishedEditFullLearnBaseline(id);
      flSig = null;
    }
    if (state.draft.id.trim() != id) return;
    state = state.copyWith(
      publishedEditReadOnlyBaselineSig: ro,
      publishedEditFullLearnBaselineSig: flSig,
    );
  }

  /// Start a brand-new local draft session (empty, new id) and persist immediately.
  Future<CreatorStoryV1> startNewLocalDraft() async {
    final next = CreatorStoryV1.empty(
      creatorOwnerId: _effectiveCreatorOwnerId(),
    );
    state = state.copyWith(
      draft: next,
      dirty: true,
      saveStatus: CreatorDraftSaveStatus.idle,
      lastSavedAt: null,
      clearLastSaveError: true,
    );
    await _drafts.saveResumeMeta(
      CreatorDraftResumeMeta.initial(
        draftId: state.draft.id,
        module: CreatorLastActiveModule.storyBasics,
      ),
    );
    await persistLocalNow(reason: 'new_draft_init');
    _hydrated = true;
    return state.draft;
  }

  void markDirty() {
    if (!state.dirty || state.saveStatus != CreatorDraftSaveStatus.idle) {
      state = state.copyWith(
        dirty: true,
        saveStatus: CreatorDraftSaveStatus.idle,
      );
    }
    if (kDebugMode) debugPrint('[creator_draft] changed');
  }

  Future<void> persistLocalNow({String reason = ''}) async {
    _persistDebounce?.cancel();
    if (kDebugMode) {
      debugPrint(
        '[creator_draft] persist_now${reason.isEmpty ? '' : ' reason=$reason'}',
      );
    }
    state = state.copyWith(
      saveStatus: CreatorDraftSaveStatus.saving,
      clearLastSaveError: true,
    );
    try {
      // Save incomplete drafts too; keep publish state + module statuses.
      final nextDraft = await _drafts.saveDraft(
        state.draft,
        remotePublishAfterPut: _remotePublishIntentForSaveReason(reason),
      );
      state = state.copyWith(
        draft: nextDraft,
        dirty: false,
        saveStatus: CreatorDraftSaveStatus.saved,
        lastSavedAt: DateTime.now(),
        clearLastSaveError: true,
      );
      if (kDebugMode) {
        debugPrint(
          '[creator_draft] saved_ok draftId=${state.draft.id.trim()} '
          'publishState=${state.draft.publishState.storageKey} '
          'hasUnpublishedCoreChanges=${state.draft.hasUnpublishedCoreChanges}',
        );
      }
      if (RemoteBackendConfig.useRemoteDrafts &&
          state.draft.publishState != StoryPublishState.draft) {
        _bumpProfileProcessingListRefresh();
      }
    } on StoryDraftValidationFailedException {
      state = state.copyWith(
        dirty: true,
        saveStatus: CreatorDraftSaveStatus.failed,
        lastSaveError: 'Validation failed',
      );
      rethrow;
    } on AppQuotaExceededException {
      state = state.copyWith(
        dirty: true,
        saveStatus: CreatorDraftSaveStatus.failed,
        clearLastSaveError: true,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        dirty: true,
        saveStatus: CreatorDraftSaveStatus.failed,
        lastSaveError: e.toString(),
      );
      if (kDebugMode) debugPrint('[creator_draft] saved_failed error=$e');
    }
  }

  /// Flush meaningful creator state so Profile > Processing reflects it.
  ///
  /// - Persists draft JSON when dirty (local/remote depending on repository).
  /// - Updates resume meta (last meaningful section) for reliable resume.
  /// - Does **not** reset any content state.
  Future<bool> flushDraftToProcessing({
    required String reason,
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
  }) async {
    _persistDebounce?.cancel();
    state = state.copyWith(
      saveStatus: CreatorDraftSaveStatus.saving,
      clearLastSaveError: true,
    );
    try {
      final id = state.draft.id.trim();
      final nowUtc = DateTime.now().toUtc();

      // If no dirty edits, avoid bumping updatedAt; still record resume meta deterministically.
      if (!state.dirty) {
        if (id.isNotEmpty &&
            (lastActiveModule != null || lastActiveSubPage != null)) {
          await _drafts.updateResumeMeta(
            id,
            lastActiveModule: lastActiveModule,
            lastActiveSubPage: lastActiveSubPage,
            touchEditedAtUtc: nowUtc,
          );
        }
        state = state.copyWith(saveStatus: CreatorDraftSaveStatus.saved);
        _bumpProfileProcessingListRefresh();
        return true;
      }

      final persisted = await _drafts.flushDraftToProcessing(
        state.draft,
        lastActiveModule: lastActiveModule,
        lastActiveSubPage: lastActiveSubPage,
        touchEditedAtUtc: nowUtc,
      );
      state = state.copyWith(
        draft: persisted,
        dirty: false,
        saveStatus: CreatorDraftSaveStatus.saved,
        lastSavedAt: DateTime.now(),
        clearLastSaveError: true,
      );
      _bumpProfileProcessingListRefresh();
      return true;
    } catch (e) {
      state = state.copyWith(
        dirty: true,
        saveStatus: CreatorDraftSaveStatus.failed,
        lastSaveError: e.toString(),
      );
      return false;
    }
  }

  /// Global reassurance action: flush pending debounced saves and force a local persist.
  ///
  /// Local-only. Never uploads. Intended for the creator shell/drawer "Save draft".
  Future<void> globalSaveDraftNow() async {
    if (kDebugMode) debugPrint('[creator_global_save] flush_pending');
    _persistDebounce?.cancel();
    await persistLocalNow(reason: 'global_save');
    if (kDebugMode) debugPrint('[creator_global_save] saved_local_ok');
    if (state.saveStatus == CreatorDraftSaveStatus.saved) {
      _bumpProfileProcessingListRefresh();
    }
  }

  void persistLocalDebounced({
    String reason = '',
    Duration delay = const Duration(milliseconds: 350),
  }) {
    markDirty();
    _persistDebounce?.cancel();
    if (kDebugMode) {
      debugPrint(
        '[creator_draft] persist_debounced${reason.isEmpty ? '' : ' reason=$reason'}',
      );
    }
    _persistDebounce = Timer(delay, () {
      unawaited(persistLocalNow(reason: reason.isEmpty ? 'debounced' : reason));
    });
  }

  // Back-compat name: callers can keep using this (routes to global-save semantics).
  Future<void> saveDraftToDisk() async => globalSaveDraftNow();

  void _setDraft(CreatorStoryV1 next, {bool dirty = true}) {
    state = state.copyWith(
      draft: next,
      dirty: dirty ? true : state.dirty,
      // Keep status as-is; persist methods will move it to saving/saved/failed.
    );
    if (dirty) markDirty();
  }

  Future<void> discardDraftFromDiskAndReset() async {
    await _drafts.clearActiveDraft();
    reset();
  }

  /// Profile / other surfaces deleted this draft id — drop session state if it matches.
  void syncIfDraftWasRemovedExternally(String draftId) {
    final id = draftId.trim();
    if (id.isEmpty) return;
    if (state.draft.id != id) return;
    _persistDebounce?.cancel();
    reset();
  }

  /// Profile / other surfaces saved this draft — refresh session if it is the same id.
  void syncIfSameDraftWasPersistedElsewhere(CreatorStoryV1 persisted) {
    if (state.draft.id != persisted.id) return;
    _persistDebounce?.cancel();
    state = state.copyWith(
      draft: persisted,
      dirty: false,
      saveStatus: CreatorDraftSaveStatus.saved,
      lastSavedAt: DateTime.now(),
      clearLastSaveError: true,
    );
    unawaited(_hydratePublishedEditBaselines(persisted.id));
  }

  void reset() => state = state.copyWith(
        draft: CreatorStoryV1.empty(
          creatorOwnerId: _effectiveCreatorOwnerId(),
        ),
        dirty: false,
        saveStatus: CreatorDraftSaveStatus.idle,
        lastSavedAt: null,
        clearLastSaveError: true,
        clearReadOnlyPublishedCoreSig: true,
        clearPublishedEditBaselines: true,
      );

  void applyBasics({
    required String title,
    required String category,
    required String level,
    required String description,
    required String promptSourceNote,
    required String? coverImageUrl,
    String? targetDurationBandKey,
  }) {
    _applyBasicsFields(
      title: title,
      category: category,
      level: level,
      description: description,
      promptSourceNote: promptSourceNote,
      coverImageUrl: coverImageUrl,
      targetDurationBandKey: targetDurationBandKey,
    );
    unawaited(persistLocalNow(reason: 'basics_confirm'));
  }

  /// Same as [applyBasics] but awaits persistence (used before navigation).
  Future<void> applyBasicsAndWaitPersist({
    required String title,
    required String category,
    required String level,
    required String description,
    required String promptSourceNote,
    required String? coverImageUrl,
    String? targetDurationBandKey,
  }) async {
    _applyBasicsFields(
      title: title,
      category: category,
      level: level,
      description: description,
      promptSourceNote: promptSourceNote,
      coverImageUrl: coverImageUrl,
      targetDurationBandKey: targetDurationBandKey,
    );
    await persistLocalNow(reason: 'basics_confirm');
  }

  /// Debounced variant for text-heavy basics fields (title/description/etc).
  ///
  /// This updates the shared draft immediately (so UI reflects changes), but
  /// persists to disk on a short debounce to avoid heavy writes per keystroke.
  void applyBasicsDebounced({
    required String title,
    required String category,
    required String level,
    required String description,
    required String promptSourceNote,
    required String? coverImageUrl,
    String? targetDurationBandKey,
    Duration delay = const Duration(milliseconds: 450),
  }) {
    _applyBasicsFields(
      title: title,
      category: category,
      level: level,
      description: description,
      promptSourceNote: promptSourceNote,
      coverImageUrl: coverImageUrl,
      targetDurationBandKey: targetDurationBandKey,
    );
    persistLocalDebounced(reason: 'basics_text', delay: delay);
  }

  void _applyBasicsFields({
    required String title,
    required String category,
    required String level,
    required String description,
    required String promptSourceNote,
    required String? coverImageUrl,
    String? targetDurationBandKey,
  }) {
    final now = DateTime.now();
    final trimmedCover = coverImageUrl?.trim();
    final cover =
        (trimmedCover == null || trimmedCover.isEmpty) ? null : trimmedCover;
    _setDraft(
      state.draft.copyWith(
        basics: state.draft.basics.copyWith(
          title: title,
          category: category,
          level: level,
          description: description,
          promptSourceNote: promptSourceNote,
          targetDurationBandKey: targetDurationBandKey,
          replaceCoverImage: true,
          coverImageUrl: cover,
          updatedAt: now,
        ),
      ),
    );
  }

  /// V1: split non-empty lines into [StorySentenceItem]s; merges with prior rows by
  /// matching [StorySentenceItem.japaneseText] so [reading] / [meanings] survive edits.
  void applySentences(String plain) {
    final list = storySentencesFromPlaintextMerge(
      storyId: state.draft.id,
      plain: plain,
      previous: state.draft.sentences,
    );
    final now = DateTime.now();
    var next = state.draft.copyWith(
      sentences: list,
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    persistLocalDebounced(reason: 'sentences_text');
  }

  /// Optional furigana + EN/MY support meanings (all optional for V1).
  void updateSentenceSupport({
    required String sentenceId,
    required LocalizedMeanings? meanings,
  }) {
    final now = DateTime.now();
    final clearM = meanings == null;
    final list = <StorySentenceItem>[
      for (final s in state.draft.sentences)
        if (s.id == sentenceId)
          s.copyWith(
            clearMeanings: clearM,
            meanings: clearM ? null : meanings,
          )
        else
          s,
    ];
    _setDraft(
      state.draft.copyWith(
        sentences: list,
        basics: state.draft.basics.copyWith(updatedAt: now),
      ),
    );
    unawaited(persistLocalNow(reason: 'sentence_support'));
  }

  void updateSentenceFurigana({
    required String sentenceId,
    required List<FuriganaSpan> spans,
  }) {
    final now = DateTime.now();
    final cleaned = spans.where((f) => f.isValid).toList();
    final list = <StorySentenceItem>[
      for (final s in state.draft.sentences)
        if (s.id == sentenceId) s.copyWith(furiganaSpans: cleaned) else s,
    ];
    _setDraft(
      state.draft.copyWith(
        sentences: list,
        basics: state.draft.basics.copyWith(updatedAt: now),
      ),
    );
    unawaited(persistLocalNow(reason: 'sentence_furigana'));
  }

  void updateSentenceTextAndFurigana({
    required String sentenceId,
    required String japaneseText,
    required List<FuriganaSpan> spans,
  }) {
    final now = DateTime.now();
    final jp = japaneseText.trim();
    if (jp.isEmpty) return;
    final cleaned = spans.where((f) => f.isValid).toList();
    final list = <StorySentenceItem>[
      for (final s in state.draft.sentences)
        if (s.id == sentenceId)
          s.copyWith(
            japaneseText: jp,
            furiganaSpans: cleaned,
          )
        else
          s,
    ];
    _setDraft(
      state.draft.copyWith(
        sentences: list,
        basics: state.draft.basics.copyWith(updatedAt: now),
      ),
    );
    unawaited(persistLocalNow(reason: 'sentence_edit'));
  }

  void markDraft() {
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.draft,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    unawaited(persistLocalNow(reason: 'publish_state'));
  }

  void publishReadingOnly() {
    if (!computeReadOnlyReady(state.draft).ready) return;
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.readingOnlyPublished,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    unawaited(persistLocalNow(reason: 'publish_state'));
  }

  bool publishReadingOnlyChecked() {
    if (!computeReadOnlyReady(state.draft).ready) return false;
    publishReadingOnly();
    return true;
  }

  void publishFullLearn() {
    if (!computeFullLearnReady(state.draft).ready) return;
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.fullLearnPublished,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    unawaited(persistLocalNow(reason: 'publish_state'));
  }

  bool publishFullLearnChecked() {
    if (!computeFullLearnReady(state.draft).ready) return false;
    publishFullLearn();
    return true;
  }

  /// Review / explicit actions: publish then await local disk flush (single completion signal).
  Future<bool> publishReadingOnlyToDisk() async {
    if (!computeReadOnlyReady(state.draft).ready) return false;
    final previousPublish = state.draft.publishState;
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.readingOnlyPublished,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    try {
      await persistLocalNow(reason: 'publish_reading_only');
    } on StoryDraftValidationFailedException {
      _setDraft(
        state.draft.copyWith(
          publishState: previousPublish,
          basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
        ),
      );
      rethrow;
    } on AppQuotaExceededException {
      _setDraft(
        state.draft.copyWith(
          publishState: previousPublish,
          basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
        ),
      );
      rethrow;
    }
    if (state.saveStatus == CreatorDraftSaveStatus.saved) {
      final sig = computeReadOnlyPublishedCoreSignature(state.draft);
      await saveReadOnlyPublishedCoreSignature(
          draftId: state.draft.id, signature: sig);
      state = state.copyWith(readOnlyPublishedCoreSig: sig);
      await _persistPublishedEditBaselinesAfterSuccessfulPublish();
      _bumpProfileProcessingListRefresh();
    }
    return state.saveStatus == CreatorDraftSaveStatus.saved;
  }

  Future<bool> publishFullLearnToDisk() async {
    if (!computeFullLearnReady(state.draft).ready) return false;
    final previousPublish = state.draft.publishState;
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.fullLearnPublished,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    try {
      await persistLocalNow(reason: 'publish_full_learn');
    } on StoryDraftValidationFailedException {
      _setDraft(
        state.draft.copyWith(
          publishState: previousPublish,
          basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
        ),
      );
      rethrow;
    } on AppQuotaExceededException {
      _setDraft(
        state.draft.copyWith(
          publishState: previousPublish,
          basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
        ),
      );
      rethrow;
    }
    if (state.saveStatus == CreatorDraftSaveStatus.saved) {
      // Full Learn implies a Read Only published baseline exists for the story core.
      final sig = computeReadOnlyPublishedCoreSignature(state.draft);
      await saveReadOnlyPublishedCoreSignature(
          draftId: state.draft.id, signature: sig);
      state = state.copyWith(readOnlyPublishedCoreSig: sig);
      await _persistPublishedEditBaselinesAfterSuccessfulPublish();
      _bumpProfileProcessingListRefresh();
    }
    return state.saveStatus == CreatorDraftSaveStatus.saved;
  }

  /// Save as draft (publish state) and persist — for flows that mark draft explicitly.
  Future<bool> markDraftAndPersistNow() async {
    _setDraft(
      state.draft.copyWith(
        publishState: StoryPublishState.draft,
        basics: state.draft.basics.copyWith(updatedAt: DateTime.now()),
      ),
    );
    await persistLocalNow(reason: 'publish_state_draft');
    if (state.saveStatus == CreatorDraftSaveStatus.saved) {
      _bumpProfileProcessingListRefresh();
    }
    return state.saveStatus == CreatorDraftSaveStatus.saved;
  }

  void setModuleStatus(LearnModuleId id, LearnModuleTaskStatus status) {
    final m = Map<LearnModuleId, LearnModuleTaskStatus>.from(
      state.draft.moduleWorkflowStatuses,
    );
    m[id] = status;
    _setDraft(state.draft.copyWith(moduleWorkflowStatuses: m));
    unawaited(persistLocalNow(reason: 'module_status'));
  }

  // ---------------------------------------------------------------------------
  // Vocab / Kanji manual editor (V1)
  // ---------------------------------------------------------------------------

  static final _uuid = Uuid();

  void addVocabKanjiEntry({
    required VocabularyKanjiEntryType type,
    required String termJapanese,
    required String readingRaw,
    required LocalizedMeanings? meanings,
    required List<VocabularyExamplePair> examplePairs,
  }) {
    final term = termJapanese.trim();
    if (term.isEmpty) return;
    final reading = readingRaw.trim();
    final pairs = _normalizeVocabExamplePairs(examplePairs);
    final legacy = _legacyMergedExampleFields(pairs);
    final entry = VocabularyKanjiEntry(
      id: _uuid.v4(),
      termJapanese: term,
      type: type,
      reading: reading.isEmpty ? null : reading,
      glosses: meanings,
      exampleSentence: legacy.$1,
      exampleMeanings: legacy.$2,
      examplePairs: pairs,
      provenance: const ContentProvenance(),
    );
    final now = DateTime.now();
    final nextLayer = VocabularyKanjiLayer(
      entries: [...state.draft.vocabularyKanji.entries, entry],
    );
    var next = state.draft.copyWith(
      vocabularyKanji: nextLayer,
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'vocab_add'));
  }

  void updateVocabKanjiEntry({
    required String entryId,
    required VocabularyKanjiEntryType type,
    required String termJapanese,
    required String readingRaw,
    required LocalizedMeanings? meanings,
    required List<VocabularyExamplePair> examplePairs,
  }) {
    final term = termJapanese.trim();
    if (term.isEmpty) return;
    final reading = readingRaw.trim();
    final pairs = _normalizeVocabExamplePairs(examplePairs);
    final legacy = _legacyMergedExampleFields(pairs);
    final now = DateTime.now();
    final nextEntries = <VocabularyKanjiEntry>[
      for (final e in state.draft.vocabularyKanji.entries)
        if (e.id == entryId)
          e.copyWith(
            type: type,
            termJapanese: term,
            clearReading: reading.isEmpty,
            reading: reading.isEmpty ? null : reading,
            clearGlosses: meanings == null,
            glosses: meanings,
            clearExampleSentence: legacy.$1 == null,
            exampleSentence: legacy.$1,
            clearExampleMeanings: legacy.$2 == null,
            exampleMeanings: legacy.$2,
            examplePairs: pairs,
          )
        else
          e,
    ];
    var next = state.draft.copyWith(
      vocabularyKanji: VocabularyKanjiLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'vocab_update'));
  }

  void deleteVocabKanjiEntry(String entryId) {
    final now = DateTime.now();
    final nextEntries = state.draft.vocabularyKanji.entries
        .where((e) => e.id != entryId)
        .toList();
    var next = state.draft.copyWith(
      vocabularyKanji: VocabularyKanjiLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'vocab_delete'));
  }

  void reorderVocabKanjiEntries(int oldIndex, int newIndex) {
    final entries = state.draft.vocabularyKanji.entries;
    if (entries.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex < 0 || newIndex > entries.length) return;
    final items = List<VocabularyKanjiEntry>.from(entries);
    var dest = newIndex;
    if (dest > oldIndex) dest -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(dest, moved);
    final now = DateTime.now();
    var next = state.draft.copyWith(
      vocabularyKanji: VocabularyKanjiLayer(entries: items),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'vocab_reorder'));
  }

  // ---------------------------------------------------------------------------
  // Grammar manual editor (V1)
  // ---------------------------------------------------------------------------

  void addGrammarEntry({
    required String headline,
    required String formRaw,
    required LocalizedMeanings? meanings,
    required LocalizedMeanings? usage,
    required List<GrammarExample> examples,
    required String mistakeWrongRaw,
    required String mistakeCorrectRaw,
    required LocalizedMeanings? relatedNote,
  }) {
    final title = headline.trim();
    if (title.isEmpty) return;
    final form = formRaw.trim();
    final wrong = mistakeWrongRaw.trim();
    final correct = mistakeCorrectRaw.trim();
    final entry = GrammarEntry(
      id: _uuid.v4(),
      headline: title,
      form: form.isEmpty ? null : form,
      meanings: meanings,
      usage: usage,
      examples: examples.where((e) => !e.isEmptyV1).toList(),
      mistakeWrong: wrong.isEmpty ? null : wrong,
      mistakeCorrect: correct.isEmpty ? null : correct,
      relatedNote: relatedNote,
      provenance: const ContentProvenance(),
    );
    final now = DateTime.now();
    final nextLayer =
        GrammarLayer(entries: [...state.draft.grammar.entries, entry]);
    var next = state.draft.copyWith(
      grammar: nextLayer,
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'grammar_add'));
  }

  void updateGrammarEntry({
    required String entryId,
    required String headline,
    required String formRaw,
    required LocalizedMeanings? meanings,
    required LocalizedMeanings? usage,
    required List<GrammarExample> examples,
    required String mistakeWrongRaw,
    required String mistakeCorrectRaw,
    required LocalizedMeanings? relatedNote,
  }) {
    final title = headline.trim();
    if (title.isEmpty) return;
    final form = formRaw.trim();
    final wrong = mistakeWrongRaw.trim();
    final correct = mistakeCorrectRaw.trim();
    final now = DateTime.now();
    final nextEntries = <GrammarEntry>[
      for (final e in state.draft.grammar.entries)
        if (e.id == entryId)
          e.copyWith(
            headline: title,
            clearForm: form.isEmpty,
            form: form.isEmpty ? null : form,
            clearMeanings: meanings == null,
            meanings: meanings,
            clearUsage: usage == null,
            usage: usage,
            examples: examples.where((x) => !x.isEmptyV1).toList(),
            clearMistakeWrong: wrong.isEmpty,
            mistakeWrong: wrong.isEmpty ? null : wrong,
            clearMistakeCorrect: correct.isEmpty,
            mistakeCorrect: correct.isEmpty ? null : correct,
            clearRelatedNote: relatedNote == null,
            relatedNote: relatedNote,
          )
        else
          e,
    ];
    var next = state.draft.copyWith(
      grammar: GrammarLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'grammar_update'));
  }

  void deleteGrammarEntry(String entryId) {
    final now = DateTime.now();
    final nextEntries =
        state.draft.grammar.entries.where((e) => e.id != entryId).toList();
    var next = state.draft.copyWith(
      grammar: GrammarLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'grammar_delete'));
  }

  void reorderGrammarEntries(int oldIndex, int newIndex) {
    final entries = state.draft.grammar.entries;
    if (entries.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex < 0 || newIndex > entries.length) return;
    final items = List<GrammarEntry>.from(entries);
    var dest = newIndex;
    if (dest > oldIndex) dest -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(dest, moved);
    final now = DateTime.now();
    var next = state.draft.copyWith(
      grammar: GrammarLayer(entries: items),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'grammar_reorder'));
  }

  // ---------------------------------------------------------------------------
  // Quiz manual editor (V1 MCQ)
  // ---------------------------------------------------------------------------

  void addQuizEntry({
    required CreatorQuizCategory category,
    required String prompt,
    required List<String> options4,
    required int correctIndex,
    required LocalizedMeanings? explanations,
    required String sourceNoteRaw,
  }) {
    final p = prompt.trim();
    if (p.isEmpty) return;
    if (options4.length != 4) return;
    final opts = [for (final o in options4) o.trim()];
    if (opts.any((o) => o.isEmpty)) return;
    if (correctIndex < 0 || correctIndex > 3) return;
    final src = sourceNoteRaw.trim();
    final entry = QuizEntry(
      id: _uuid.v4(),
      category: category,
      prompt: p,
      options: opts,
      correctIndex: correctIndex,
      explanations: explanations,
      sourceNote: src.isEmpty ? null : src,
      provenance: const ContentProvenance(),
    );
    final now = DateTime.now();
    final nextLayer = QuizLayer(entries: [...state.draft.quiz.entries, entry]);
    var next = state.draft.copyWith(
      quiz: nextLayer,
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'quiz_add'));
  }

  void updateQuizEntry({
    required String entryId,
    required CreatorQuizCategory category,
    required String prompt,
    required List<String> options4,
    required int correctIndex,
    required LocalizedMeanings? explanations,
    required String sourceNoteRaw,
  }) {
    final p = prompt.trim();
    if (p.isEmpty) return;
    if (options4.length != 4) return;
    final opts = [for (final o in options4) o.trim()];
    if (opts.any((o) => o.isEmpty)) return;
    if (correctIndex < 0 || correctIndex > 3) return;
    final src = sourceNoteRaw.trim();
    final now = DateTime.now();
    final nextEntries = <QuizEntry>[
      for (final e in state.draft.quiz.entries)
        if (e.id == entryId)
          e.copyWith(
            category: category,
            prompt: p,
            options: opts,
            correctIndex: correctIndex,
            clearExplanations: explanations == null,
            explanations: explanations,
            clearSourceNote: src.isEmpty,
            sourceNote: src.isEmpty ? null : src,
          )
        else
          e,
    ];
    var next = state.draft.copyWith(
      quiz: QuizLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'quiz_update'));
  }

  void deleteQuizEntry(String entryId) {
    final now = DateTime.now();
    final nextEntries =
        state.draft.quiz.entries.where((e) => e.id != entryId).toList();
    var next = state.draft.copyWith(
      quiz: QuizLayer(entries: nextEntries),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'quiz_delete'));
  }

  /// Reorder quiz entries whose [categories] match (e.g. Semantics = vocab + kanji).
  ///
  /// The quiz layer stores a single list; this keeps relative ordering between
  /// different categories stable while still allowing per-tab reordering.
  void reorderQuizEntryWithinCategories({
    required Set<CreatorQuizCategory> categories,
    required int oldIndexInCategory,
    required int newIndexInCategory,
  }) {
    if (oldIndexInCategory == newIndexInCategory) return;
    final all = [...state.draft.quiz.entries];
    final indices = <int>[
      for (var i = 0; i < all.length; i++)
        if (categories.contains(all[i].category)) i,
    ];
    if (indices.isEmpty) return;
    if (oldIndexInCategory < 0 || oldIndexInCategory >= indices.length) return;
    if (newIndexInCategory < 0 || newIndexInCategory >= indices.length) return;

    final from = indices[oldIndexInCategory];
    var to = indices[newIndexInCategory];
    // When removing earlier element, destination shifts left.
    if (from < to) to -= 1;

    final moved = all.removeAt(from);
    all.insert(to, moved);

    final now = DateTime.now();
    var next = state.draft.copyWith(
      quiz: QuizLayer(entries: all),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'quiz_reorder'));
  }

  /// Reorder quiz entries within one [category] only (V1).
  void reorderQuizEntryWithinCategory({
    required CreatorQuizCategory category,
    required int oldIndexInCategory,
    required int newIndexInCategory,
  }) {
    reorderQuizEntryWithinCategories(
      categories: {category},
      oldIndexInCategory: oldIndexInCategory,
      newIndexInCategory: newIndexInCategory,
    );
  }

  // ---------------------------------------------------------------------------
  // Story-level audio editor (V1)
  // ---------------------------------------------------------------------------

  static const _v1AllowedAudioExtensions = <String>{'mp3', 'm4a', 'wav'};

  static String? _extensionOfFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).trim().toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  void setStoryAudio({
    required String sourceUrlRaw,
    required String displayNameRaw,
    required int? durationSeconds,
  }) {
    final url = sourceUrlRaw.trim();
    if (!isPublicHttpAudioSourceUrl(url)) return;
    final name = displayNameRaw.trim();
    final now = DateTime.now();
    final asset = StoryAudioAsset(
      id: _uuid.v4(),
      sourceUrl: url,
      displayName: name.isEmpty ? null : name,
      durationSeconds: durationSeconds,
      provenance: const ContentProvenance(),
    );
    var next = state.draft.copyWith(
      audio: AudioLayer(storyAudio: asset),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'audio_set'));
  }

  /// V1 creator-facing "upload audio" flow.
  ///
  /// This keeps [StoryAudioAsset.sourceUrl] as an internal reference (may be a
  /// future uploaded URL), while the creator UI is driven by local file metadata.
  void setStoryAudioFromPickedFile({
    required String pickedFileName,
    required String? pickedPath,
    required int? pickedSizeBytes,
    required String displayNameRaw,
    required int? durationSeconds,
  }) {
    final fileName = pickedFileName.trim();
    if (fileName.isEmpty) return;
    final ext = _extensionOfFileName(fileName);
    if (ext == null || !_v1AllowedAudioExtensions.contains(ext)) return;

    final name = displayNameRaw.trim();
    final now = DateTime.now();

    // Internal compat: keep a non-http source reference even before uploads exist.
    // The creator UI must not rely on this value.
    final internalRef = (pickedPath == null || pickedPath.trim().isEmpty)
        ? 'local://$fileName'
        : pickedPath.trim();

    final asset = StoryAudioAsset(
      id: _uuid.v4(),
      sourceUrl: internalRef,
      localFileName: fileName,
      localPath: (pickedPath == null || pickedPath.trim().isEmpty)
          ? null
          : pickedPath.trim(),
      localSizeBytes: pickedSizeBytes,
      localExtension: ext,
      displayName: name.isEmpty ? null : name,
      durationSeconds: durationSeconds,
      provenance: const ContentProvenance(),
    );

    var next = state.draft.copyWith(
      audio: AudioLayer(storyAudio: asset),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'audio_pick'));
  }

  void clearStoryAudio() {
    final now = DateTime.now();
    var next = state.draft.copyWith(
      audio: const AudioLayer(storyAudio: null),
      basics: state.draft.basics.copyWith(updatedAt: now),
    );
    next = syncModuleWorkflowWithContent(next);
    _setDraft(next);
    unawaited(persistLocalNow(reason: 'audio_clear'));
  }
}

final storyCreatorDraftProvider =
    StateNotifierProvider<StoryCreatorDraftNotifier, StoryCreatorDraftState>(
        (ref) {
  return StoryCreatorDraftNotifier(
    ref.watch(storyDraftRepositoryProvider),
    ref.watch(currentUserIdProvider),
    onProfileProcessingListChanged: () {
      final c = ref.read(profileProcessingListRefreshProvider.notifier);
      c.state = c.state + 1;
    },
  );
});

/// Convenience: most UIs only need the draft content, not save meta.
final storyCreatorDraftDataProvider = Provider<CreatorStoryV1>((ref) {
  return ref.watch(storyCreatorDraftProvider).draft;
});
