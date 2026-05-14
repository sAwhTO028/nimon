/// Minimal backend config for the Add-flow remote repository.
///
/// Override at runtime with:
/// - `--dart-define=NIMON_USE_REMOTE_DRAFTS=true`
/// - `--dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000` (Android emulator)
/// - `--dart-define=NIMON_STRICT_REMOTE_DRAFTS=true` (fail loudly; no silent fallback)
abstract final class RemoteBackendConfig {
  RemoteBackendConfig._();

  static const bool useRemoteDrafts =
      bool.fromEnvironment('NIMON_USE_REMOTE_DRAFTS', defaultValue: false);

  static const String apiBaseUrl = String.fromEnvironment(
    'NIMON_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Public web origin for share links (`/mono/:id`). **Not** the uploads base
  /// ([MEDIA_PUBLIC_BASE_URL] on the server). Leave empty to prefer the backend
  /// [MonoFeedItem.shareUrl]; optional fallback uses [apiBaseUrl] when it is not loopback.
  ///
  /// `--dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000`
  static const String publicWebBaseUrl = String.fromEnvironment(
    'NIMON_PUBLIC_WEB_BASE_URL',
    defaultValue: '',
  );

  /// Dev owner id sent on draft writes (`basics.ownerId` / `creatorOwnerId`).
  ///
  /// Must match the Nest `DEV_OWNER_ID` env var when set, otherwise the backend
  /// default `00000000-0000-0000-0000-000000000001` (see `StoryDraftsService` in nimon-backend).
  ///
  /// Override with `--dart-define=NIMON_DEV_OWNER_ID=<uuid>` if your server uses a non-default id.
  static const String devOwnerId = String.fromEnvironment(
    'NIMON_DEV_OWNER_ID',
    defaultValue: '00000000-0000-0000-0000-000000000001',
  );

  /// Dev-only strict mode for remote draft persistence.
  ///
  /// Why: the remote repository can fall back to local storage for resilience,
  /// but that can mask backend/API failures during development.
  ///
  /// When enabled alongside [useRemoteDrafts], remote operations throw instead of
  /// silently returning local fallback results.
  static const bool strictRemoteDrafts =
      bool.fromEnvironment('NIMON_STRICT_REMOTE_DRAFTS', defaultValue: false);

  /// When true, Mono Home can use [RemoteMonoFeedRepository] instead of mock feed data.
  ///
  /// `--dart-define=NIMON_USE_REMOTE_MONO_FEED=true`
  static const bool useRemoteMonoFeed =
      bool.fromEnvironment('NIMON_USE_REMOTE_MONO_FEED', defaultValue: false);

  /// When true, Creator Listening audio sheet exposes **public URL** and **attach without uploading**.
  ///
  /// Normal release builds omit these paths (`false`). Enable for internal/support tooling:
  /// `--dart-define=NIMON_CREATOR_AUDIO_ADVANCED=true`
  static const bool creatorAudioAdvancedUxEnabled =
      bool.fromEnvironment('NIMON_CREATOR_AUDIO_ADVANCED', defaultValue: false);
}
