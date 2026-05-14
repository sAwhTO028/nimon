import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  return RemoteUserPreferencesRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

class UserPreferencesState {
  const UserPreferencesState({
    required this.loading,
    required this.saving,
    required this.prefs,
    this.errorMessage,
  });

  final bool loading;
  final bool saving;
  final UserPreferences prefs;
  final String? errorMessage;

  UserPreferencesState copyWith({
    bool? loading,
    bool? saving,
    UserPreferences? prefs,
    String? errorMessage,
  }) {
    return UserPreferencesState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      prefs: prefs ?? this.prefs,
      errorMessage: errorMessage,
    );
  }

  static const initial = UserPreferencesState(
    loading: true,
    saving: false,
    prefs: UserPreferences.defaults,
    errorMessage: null,
  );
}

final userPreferencesNotifierProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferencesState>((ref) {
  return UserPreferencesNotifier(
    ref,
    repo: ref.watch(userPreferencesRepositoryProvider),
  );
});

class UserPreferencesNotifier extends StateNotifier<UserPreferencesState> {
  UserPreferencesNotifier(this._ref, {required UserPreferencesRepository repo})
      : _repo = repo,
        super(UserPreferencesState.initial) {
    // M11d: App locale depends on preferences globally, not just Settings screen.
    // Bootstrap preferences once when provider is first created.
    unawaited(Future<void>.microtask(load));
  }

  final UserPreferencesRepository _repo;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final prefs = await _repo.fetchPreferences();
      state = state.copyWith(loading: false, prefs: prefs, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e is StateError ? e.message : 'Could not load settings.',
      );
    }
  }

  Future<void> _patchAndUpdate(Future<UserPreferences> Function() run) async {
    if (state.saving) return;
    state = state.copyWith(saving: true, errorMessage: null);
    try {
      final prefs = await run();
      state = state.copyWith(saving: false, prefs: prefs, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        saving: false,
        errorMessage: e is StateError ? e.message : 'Could not save settings.',
      );
      // Best-effort reload to avoid UI drifting from server truth.
      unawaited(load());
    }
  }

  Future<void> updateAppLocale(String code) async {
    await _patchAndUpdate(() => _repo.patchPreferences(appLocale: code));
  }

  Future<void> updateContentLocale(String code) async {
    await _patchAndUpdate(() => _repo.patchPreferences(contentLocale: code));
    // M11e: changing content community should reload reels/feed from the first page.
    unawaited(_ref.read(monoFeedPagerProvider.notifier).refresh());
    unawaited(_ref.read(followingMonoFeedPagerProvider.notifier).refresh());
  }

  Future<void> updateLearningLanguage(String code) async {
    await _patchAndUpdate(() => _repo.patchPreferences(learningLanguage: code));
    // M11e: changing learning language should reload reels/feed from the first page.
    unawaited(_ref.read(monoFeedPagerProvider.notifier).refresh());
    unawaited(_ref.read(followingMonoFeedPagerProvider.notifier).refresh());
  }

  Future<void> updateThemeMode(String code) async {
    await _patchAndUpdate(() => _repo.patchPreferences(themeMode: code));
  }

  Future<void> updateReadingTextSize(String code) async {
    await _patchAndUpdate(() => _repo.patchPreferences(readingTextSize: code));
  }

  Future<void> updateShowExplanations(bool value) async {
    await _patchAndUpdate(
        () => _repo.patchPreferences(showExplanations: value));
  }
}
