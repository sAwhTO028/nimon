import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/core/validation/form_validation_adapter.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/profile_validators.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/core/media/media_upload_error_mapper.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/data/media_upload_repository_provider.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/data/remote_me_profile_repository.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/features/profile/presentation/providers/profile_saved_mono_pager.dart';

final remoteMeProfileRepositoryProvider = Provider<MeProfileRepository>((ref) {
  return RemoteMeProfileRepository(
    apiBaseUrl: RemoteBackendConfig.apiBaseUrl,
    authHeaderBuilder: ref.watch(authHeaderBuilderProvider),
    sendWithAuth401Recovery: ref.watch(nimonSendWithAuth401RecoveryProvider),
  );
});

typedef EditProfilePickImageFn = Future<XFile?> Function({
  required ImageSource source,
});

final editProfilePickImageProvider = Provider<EditProfilePickImageFn>((ref) {
  final picker = ImagePicker();
  return ({required ImageSource source}) {
    return picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
  };
});

class EditProfileState {
  const EditProfileState({
    required this.loading,
    required this.saving,
    required this.uploadingAvatar,
    required this.uploadingCover,
    required this.email,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.coverImageUrl,
    required this.bio,
    this.errorMessage,
    this.lastSavedAtMs,
    this.profileFieldErrors = const {},
    this.profileBannerIssue,
    this.mediaUploadError,
    this.mediaUploadSurface,
  });

  final bool loading;
  final bool saving;
  final bool uploadingAvatar;
  final bool uploadingCover;

  final String email;
  final String displayName;
  final String handle;
  final String avatarUrl;
  final String coverImageUrl;
  final String bio;

  final String? errorMessage;
  final int? lastSavedAtMs;

  /// Keys: [validateDisplayName] / [validateHandle] / [validateBio] `field` ids.
  final Map<String, ValidationIssue> profileFieldErrors;

  /// HTTP validation issue not mapped to a profile field (shown as snackbar).
  final ValidationIssue? profileBannerIssue;

  /// Raw upload failure for localized messaging in UI.
  final Object? mediaUploadError;
  final MediaUploadSurface? mediaUploadSurface;

  bool get hasLoaded =>
      !loading &&
      (email.isNotEmpty ||
          displayName.isNotEmpty ||
          handle.isNotEmpty ||
          avatarUrl.isNotEmpty ||
          coverImageUrl.isNotEmpty ||
          bio.isNotEmpty);

  EditProfileState copyWith({
    bool? loading,
    bool? saving,
    bool? uploadingAvatar,
    bool? uploadingCover,
    String? email,
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? coverImageUrl,
    String? bio,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? lastSavedAtMs,
    Map<String, ValidationIssue>? profileFieldErrors,
    ValidationIssue? profileBannerIssue,
    bool clearProfileBannerIssue = false,
    Object? mediaUploadError,
    MediaUploadSurface? mediaUploadSurface,
    bool clearMediaUpload = false,
  }) {
    return EditProfileState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
      uploadingCover: uploadingCover ?? this.uploadingCover,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bio: bio ?? this.bio,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
      profileFieldErrors: profileFieldErrors ?? this.profileFieldErrors,
      profileBannerIssue: clearProfileBannerIssue
          ? null
          : (profileBannerIssue ?? this.profileBannerIssue),
      mediaUploadError:
          clearMediaUpload ? null : (mediaUploadError ?? this.mediaUploadError),
      mediaUploadSurface: clearMediaUpload
          ? null
          : (mediaUploadSurface ?? this.mediaUploadSurface),
    );
  }

  static const empty = EditProfileState(
    loading: true,
    saving: false,
    uploadingAvatar: false,
    uploadingCover: false,
    email: '',
    displayName: '',
    handle: '',
    avatarUrl: '',
    coverImageUrl: '',
    bio: '',
    errorMessage: null,
    lastSavedAtMs: null,
    profileFieldErrors: {},
    profileBannerIssue: null,
    mediaUploadError: null,
    mediaUploadSurface: null,
  );
}

final editProfileNotifierProvider =
    StateNotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>(
        (ref) {
  return EditProfileNotifier(
    ref,
    repo: ref.watch(remoteMeProfileRepositoryProvider),
  );
});

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  EditProfileNotifier(this._ref, {required MeProfileRepository repo})
      : _repo = repo,
        super(EditProfileState.empty);

  final Ref _ref;
  final MeProfileRepository _repo;

  MediaUploadRepository get _uploads =>
      _ref.read(mediaUploadRepositoryProvider);
  EditProfilePickImageFn get _pick => _ref.read(editProfilePickImageProvider);

  Future<void> load() async {
    state = state.copyWith(
      loading: true,
      clearErrorMessage: true,
      clearProfileBannerIssue: true,
      clearMediaUpload: true,
      profileFieldErrors: {},
    );
    try {
      final res = await _repo.fetchMyProfile();
      state = state.copyWith(
        loading: false,
        saving: false,
        email: (res.email ?? '').trim(),
        displayName: (res.displayName ?? '').trim(),
        handle: (res.handle ?? '').trim(),
        avatarUrl: (res.avatarUrl ?? '').trim(),
        coverImageUrl: (res.coverImageUrl ?? '').trim(),
        bio: (res.bio ?? '').trim(),
        clearErrorMessage: true,
        clearProfileBannerIssue: true,
        clearMediaUpload: true,
        profileFieldErrors: {},
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e is StateError ? e.message : 'Could not load profile.',
        clearProfileBannerIssue: true,
      );
    }
  }

  void setDisplayName(String v) {
    final fe = Map<String, ValidationIssue>.from(state.profileFieldErrors);
    fe.remove('displayName');
    state = state.copyWith(displayName: v, profileFieldErrors: fe);
  }

  void setHandle(String v) {
    final fe = Map<String, ValidationIssue>.from(state.profileFieldErrors);
    fe.remove('handle');
    state = state.copyWith(handle: v, profileFieldErrors: fe);
  }

  void setAvatarUrl(String v) => state = state.copyWith(avatarUrl: v);
  void setCoverImageUrl(String v) => state = state.copyWith(coverImageUrl: v);

  void setBio(String v) {
    final fe = Map<String, ValidationIssue>.from(state.profileFieldErrors);
    fe.remove('bio');
    state = state.copyWith(bio: v, profileFieldErrors: fe);
  }

  Future<void> pickAndUploadAvatar({ImageSource source = ImageSource.gallery}) {
    return _pickAndUpload(
      source: source,
      kind: _UploadKind.avatar,
    );
  }

  Future<void> pickAndUploadCover({ImageSource source = ImageSource.gallery}) {
    return _pickAndUpload(
      source: source,
      kind: _UploadKind.cover,
    );
  }

  Future<void> _pickAndUpload({
    required ImageSource source,
    required _UploadKind kind,
  }) async {
    if (kind == _UploadKind.avatar && state.uploadingAvatar) return;
    if (kind == _UploadKind.cover && state.uploadingCover) return;
    if (state.saving) return;

    state = state.copyWith(
      clearErrorMessage: true,
      clearProfileBannerIssue: true,
      clearMediaUpload: true,
      uploadingAvatar: kind == _UploadKind.avatar ? true : null,
      uploadingCover: kind == _UploadKind.cover ? true : null,
    );

    try {
      final file = await _pick(source: source);
      if (file == null) {
        // User canceled.
        return;
      }

      // Endpoint strategy (M9c): reuse `POST /v1/media/upload/cover` for both
      // avatar and cover until dedicated endpoints exist.
      final res = await _uploads.uploadCover(file);
      if (kind == _UploadKind.avatar) {
        state = state.copyWith(avatarUrl: res.url.trim());
      } else {
        state = state.copyWith(coverImageUrl: res.url.trim());
      }
    } catch (e) {
      state = state.copyWith(
        clearErrorMessage: true,
        clearProfileBannerIssue: true,
        mediaUploadError: e,
        mediaUploadSurface: kind == _UploadKind.avatar
            ? MediaUploadSurface.profileAvatar
            : MediaUploadSurface.profileCover,
      );
    } finally {
      state = state.copyWith(
        uploadingAvatar: kind == _UploadKind.avatar ? false : null,
        uploadingCover: kind == _UploadKind.cover ? false : null,
      );
    }
  }

  Future<void> save() async {
    if (state.saving) return;
    state = state.copyWith(
      saving: true,
      errorMessage: null,
      profileFieldErrors: {},
    );

    String? norm(String raw) {
      final t = raw.trim();
      return t.isEmpty ? '' : t;
    }

    // Send **empty string** to clear field (backend normalizes -> null).
    final displayName = norm(state.displayName) ?? '';
    var handle = norm(state.handle) ?? '';
    if (handle.startsWith('@')) {
      handle = handle.substring(1);
    }
    final avatarUrl = norm(state.avatarUrl) ?? '';
    final coverImageUrl = norm(state.coverImageUrl) ?? '';
    final bio = norm(state.bio) ?? '';

    final dnRes = validateDisplayName(displayName);
    final hRes = validateHandle(state.handle);
    final bRes = validateBio(bio.isEmpty ? null : bio);
    if (!dnRes.ok || !hRes.ok || !bRes.ok) {
      final dnErr = firstBlockingIssueForField(dnRes, 'displayName');
      final hErr = firstBlockingIssueForField(hRes, 'handle');
      final bErr = firstBlockingIssueForField(bRes, 'bio');
      state = state.copyWith(
        saving: false,
        profileFieldErrors: {
          if (dnErr != null) 'displayName': dnErr,
          if (hErr != null) 'handle': hErr,
          if (bErr != null) 'bio': bErr,
        },
      );
      return;
    }

    try {
      await _repo.patchMyProfile(
        displayName: displayName,
        handle: handle,
        avatarUrl: avatarUrl,
        coverImageUrl: coverImageUrl,
        bio: bio,
      );

      // Refresh session header fields (displayName/handle).
      unawaited(_ref.read(authSessionProvider.notifier).restoreSession());

      // Refresh owner header public profile cache (bio/avatar/cover).
      _ref.invalidate(currentUserPublicProfileProvider);

      unawaited(_ref.read(monoFeedPagerProvider.notifier).refresh());
      unawaited(_ref.read(followingMonoFeedPagerProvider.notifier).refresh());
      unawaited(
        _ref.read(profilePublishedMonoPagerProvider.notifier).refresh(),
      );
      unawaited(_ref.read(profileSavedMonoPagerProvider.notifier).refresh());
      unawaited(
        _ref.read(myCreatorCollectionsNotifierProvider.notifier).load(),
      );

      state = state.copyWith(
        saving: false,
        clearErrorMessage: true,
        clearProfileBannerIssue: true,
        profileFieldErrors: {},
        lastSavedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on HttpValidationFailedException catch (e) {
      final fe = blockingIssuesByField(e.issues);
      final extra = firstUnhandledBlockingIssue(e.issues, fe.keys.toSet());
      state = state.copyWith(
        saving: false,
        profileFieldErrors: fe,
        clearErrorMessage: true,
        profileBannerIssue: extra,
        clearProfileBannerIssue: extra == null,
      );
    } catch (e) {
      state = state.copyWith(
        saving: false,
        errorMessage: e is StateError
            ? e.message
            : 'Could not save profile. Please try again.',
        clearProfileBannerIssue: true,
      );
    }
  }
}

enum _UploadKind { avatar, cover }
