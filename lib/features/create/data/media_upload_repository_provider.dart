import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

/// Shared [MediaUploadRepository] for M5c cover/audio uploads.
final mediaUploadRepositoryProvider = Provider<MediaUploadRepository>((ref) {
  return MediaUploadRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});
