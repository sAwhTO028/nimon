import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';

class _FakeUserPreferencesRepository implements UserPreferencesRepository {
  _FakeUserPreferencesRepository(this._prefs);

  UserPreferences _prefs;

  @override
  Future<UserPreferences> fetchPreferences() async => _prefs;

  @override
  Future<UserPreferences> patchPreferences({
    String? appLocale,
    String? contentLocale,
    String? learningLanguage,
    String? themeMode,
    String? readingTextSize,
    bool? showExplanations,
  }) async {
    _prefs = _prefs.copyWith(
      appLocale: appLocale,
      contentLocale: contentLocale,
      learningLanguage: learningLanguage,
      themeMode: themeMode,
      readingTextSize: readingTextSize,
      showExplanations: showExplanations,
    );
    return _prefs;
  }
}

class _NoopMonoFeedRepo implements MonoFeedRepository {
  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) async {
    return const PageResult(
        items: <MonoFeedSummaryDto>[], nextCursor: null, hasMore: false);
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) {
    throw UnimplementedError();
  }
}

class _TestMonoFeedPager extends MonoFeedPager {
  _TestMonoFeedPager(super.repo);

  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _TestFollowingPager extends FollowingMonoFeedPager {
  _TestFollowingPager(super.repo);

  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

void main() {
  test('updateContentLocale triggers feed refresh on both pagers', () async {
    final fakePrefsRepo =
        _FakeUserPreferencesRepository(UserPreferences.defaults);
    final monoRepo = _NoopMonoFeedRepo();
    final monoPager = _TestMonoFeedPager(monoRepo);
    final followingPager = _TestFollowingPager(monoRepo);

    final container = ProviderContainer(
      overrides: [
        userPreferencesRepositoryProvider.overrideWithValue(fakePrefsRepo),
        remoteMonoFeedRepositoryProvider.overrideWithValue(monoRepo),
        remoteFollowingMonoFeedRepositoryProvider.overrideWithValue(monoRepo),
        monoFeedPagerProvider.overrideWith(
          (_) => monoPager as MonoFeedPager,
        ),
        followingMonoFeedPagerProvider.overrideWith(
          (_) => followingPager as FollowingMonoFeedPager,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(userPreferencesNotifierProvider.notifier);
    await notifier.updateContentLocale('my');
    // Allow unawaited refresh() calls to run.
    await Future<void>.delayed(Duration.zero);

    expect(monoPager.refreshCalls, greaterThanOrEqualTo(1));
    expect(followingPager.refreshCalls, greaterThanOrEqualTo(1));
  });

  test('updateLearningLanguage triggers feed refresh on both pagers', () async {
    final fakePrefsRepo =
        _FakeUserPreferencesRepository(UserPreferences.defaults);
    final monoRepo = _NoopMonoFeedRepo();
    final monoPager = _TestMonoFeedPager(monoRepo);
    final followingPager = _TestFollowingPager(monoRepo);

    final container = ProviderContainer(
      overrides: [
        userPreferencesRepositoryProvider.overrideWithValue(fakePrefsRepo),
        remoteMonoFeedRepositoryProvider.overrideWithValue(monoRepo),
        remoteFollowingMonoFeedRepositoryProvider.overrideWithValue(monoRepo),
        monoFeedPagerProvider.overrideWith(
          (_) => monoPager as MonoFeedPager,
        ),
        followingMonoFeedPagerProvider.overrideWith(
          (_) => followingPager as FollowingMonoFeedPager,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(userPreferencesNotifierProvider.notifier);
    await notifier.updateLearningLanguage('ja');
    await Future<void>.delayed(Duration.zero);

    expect(monoPager.refreshCalls, greaterThanOrEqualTo(1));
    expect(followingPager.refreshCalls, greaterThanOrEqualTo(1));
  });
}
