import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';

/// Override in tests or when a remote-capable implementation exists.
final storyDraftRepositoryProvider = Provider<StoryDraftRepository>((ref) {
  if (RemoteBackendConfig.useRemoteDrafts) {
    return RemoteStoryDraftRepository(apiBaseUrl: RemoteBackendConfig.apiBaseUrl);
  }
  return const LocalStoryDraftRepository();
});
