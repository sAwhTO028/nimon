import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/current_user_id_provider.dart';
import 'package:nimon/features/create/creator_publish_status_provider.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';

/// Override in tests or when a remote-capable implementation exists.
final storyDraftRepositoryProvider = Provider<StoryDraftRepository>((ref) {
  if (RemoteBackendConfig.useRemoteDrafts) {
    return RemoteStoryDraftRepository(
      apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
      authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
      sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
      resolveRemoteOwnerId: () => ref.read(currentUserIdProvider),
      onPublishProgress: (msg) {
        ref.read(creatorPublishStatusTextProvider.notifier).state = msg;
      },
    );
  }
  return const LocalStoryDraftRepository();
});
