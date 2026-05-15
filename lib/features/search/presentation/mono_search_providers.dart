import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/search/data/remote_mono_search_repository.dart';
import 'package:nimon/features/search/presentation/mono_search_notifier.dart';
import 'package:nimon/features/search/presentation/mono_search_state.dart';

/// Default remote search repo (override in tests).
final remoteMonoSearchRepositoryProvider =
    Provider<RemoteMonoSearchRepository>((ref) {
  return RemoteMonoSearchRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

final monoSearchNotifierProvider =
    StateNotifierProvider.autoDispose<MonoSearchNotifier, MonoSearchState>(
  (ref) {
    return MonoSearchNotifier(
      ref.watch(remoteMonoSearchRepositoryProvider),
    );
  },
);
