# M9c Profile Image Upload Wiring Report

## Scope
- Add user-friendly avatar + cover image picker and upload wiring to Edit Profile.
- Reuse existing media upload infrastructure.
- Keep email read-only; keep display name / handle / bio unchanged.
- Save still required to persist uploaded URLs via `PATCH /v1/me/profile`.

## Upload Endpoint Strategy
- **Reused existing endpoint**: `POST /v1/media/upload/cover`
  - Used for both **avatar** and **profile cover** images in M9c.
  - Rationale: backend currently exposes `upload/cover` and `upload/audio` only; no profile-specific upload routes exist yet.
  - Follow-up: if/when backend adds dedicated avatar/cover endpoints, swap the repository call without changing UI/state shape.

## Files Changed
- `lib/features/profile/edit_profile_screen.dart`
- `lib/features/profile/presentation/providers/edit_profile_notifier.dart`
- `test/features/profile/edit_profile_screen_test.dart`
- `docs/M9C_PROFILE_IMAGE_UPLOAD_WIRING_REPORT.md` (new)

## Avatar Upload
- Avatar preview is tappable + a **Change photo** button is shown.
- Flow:
  - pick image (gallery)
  - upload via `MediaUploadRepository.uploadCover`
  - update `EditProfileState.avatarUrl`
  - user hits **Save** to PATCH `avatarUrl`

## Cover Upload
- Cover preview is tappable + a **Change cover** button is shown.
- Flow mirrors avatar:
  - pick image (gallery)
  - upload via `MediaUploadRepository.uploadCover`
  - update `EditProfileState.coverImageUrl`
  - user hits **Save** to PATCH `coverImageUrl`

## UI Changes
- Primary V1 UI shows:
  - cover preview + Change cover
  - avatar preview + Change photo
- Manual URL fields are **debug-only** (visible in `kDebugMode`) for troubleshooting.

## State Handling
- Added upload state:
  - `uploadingAvatar`
  - `uploadingCover`
- Save is disabled while either upload is in progress.
- Upload errors are surfaced via existing snackbar mechanism (`errorMessage`).
- Upload taps are disabled while the respective upload is running.

## Tests Added
- Edit profile shows **Change cover** / **Change photo**.
- Avatar upload success -> PATCH body includes `avatarUrl`.
- Cover upload success -> PATCH body includes `coverImageUrl`.
- Upload failure shows friendly message and does not apply a URL.

## Commands Run
- `dart format` (touched files)
- `flutter analyze` (touched paths)
- `flutter test test/features/profile`
- `flutter test`

## Manual Verification
- Open owner profile drawer -> Edit profile.
- Tap **Change photo** and pick an image:
  - upload progress indicator shown
  - avatar preview updates after upload
- Tap **Change cover** and pick an image:
  - upload progress indicator shown
  - cover preview updates after upload
- Tap **Save**:
  - profile persists and refresh behavior from M9b still runs.

## Remaining Risks
- Reusing `/v1/media/upload/cover` means avatar images are stored/treated as "cover" media server-side (naming/pathing), which may be acceptable short-term but should be clarified for production.
- Image cropping/resizing is not implemented (future UX polish).

## Recommended Next Step
- Add dedicated backend endpoints for avatar vs profile cover (optional), or add server-side typing so media is categorized correctly.
- Add crop controls (circle crop for avatar) and better compression presets.

