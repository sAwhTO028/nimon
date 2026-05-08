import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:nimon/features/create/data/remote_backend_config.dart';

/// Whether Mono may show **mock** bookmark “folder/collection” demo UI.
///
/// Off for production-style builds that use remote Mono feed and/or remote
/// profile (drafts gate Saved tab) — see M8c1 Saved-only polish.
bool get monoDemoBookmarkFoldersEnabled => savedOnlyUxDemoFoldersEnabled(
      isDebugMode: kDebugMode,
      useRemoteMonoFeed: RemoteBackendConfig.useRemoteMonoFeed,
      useRemoteDrafts: RemoteBackendConfig.useRemoteDrafts,
    );

@visibleForTesting
bool savedOnlyUxDemoFoldersEnabled({
  required bool isDebugMode,
  required bool useRemoteMonoFeed,
  required bool useRemoteDrafts,
}) =>
    isDebugMode && !useRemoteMonoFeed && !useRemoteDrafts;
