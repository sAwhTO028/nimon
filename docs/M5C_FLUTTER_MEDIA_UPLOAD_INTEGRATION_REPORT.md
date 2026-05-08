# M5c Flutter Media Upload Integration Report

## Files Changed

| Area | Path |
|------|------|
| Upload client | `lib/features/create/data/media_upload_repository.dart` |
| Riverpod | `lib/features/create/data/media_upload_repository_provider.dart` |
| Cover URL helper | `lib/features/create/story_basics_remote_cover_url.dart` |
| Story basics form | `lib/features/create/create_story_basics_form.dart` |
| Creator basics route | `lib/features/create/story_creator_basics_screen.dart` |
| Dock Create flow | `lib/features/create/create_screen.dart` |
| Listening audio UI | `lib/features/create/story_creator_audio_editor_screen.dart` |
| Tests | `test/features/create/media_upload_repository_test.dart` |
| | `test/features/create/story_basics_remote_cover_url_test.dart` |
| | `test/features/create/story_creator_public_audio_url_test.dart` (extended) |

Backend, Prisma, and publish snapshot shapes were not modified.

## Upload Repository

- **`MediaUploadRepository`** (`media_upload_repository.dart`):  
  - **`uploadCover(XFile)`** → `POST {apiBaseUrl}/v1/media/upload/cover`, multipart field **`file`**.  
  - **`uploadAudio`** / **`uploadAudioPlatformFile`** → `POST …/v1/media/upload/audio`, field **`file`** (bytes or native path for streaming when possible).  
- **`MediaUploadResponse`**: `url`, `mediaType`, `originalName`, `sizeBytes`, `durationSeconds` (parsed from JSON; duration often null today).  
- **`mediaUploadRepositoryProvider`**: uses **`RemoteBackendConfig.apiBaseUrl`** and **`authHeaderBuilderProvider`** for **`Authorization: Bearer …`**.  
- Empty auth → **`MediaUploadException('Sign in to upload media.')`** (no `DEV_OWNER` / dev-owner fallback).  
- **`notifyIfStrictUnauthorized401`** is invoked on HTTP **401** responses (same strict-session bridge as remote drafts).

## Cover Upload Flow

- **`CreateStoryBasicsForm`** accepts optional **`onCoverUpload`**. **`StoryCreatorBasicsScreen`** and **`CreateScreen`** provide an upload closure that checks **`authTokenStoreProvider`**, shows **“Sign in to upload media.”** when there is no access token, then calls **`MediaUploadRepository.uploadCover`**.  
- On pick: shows **uploading** overlay on the thumbnail; on success sets **`_coverNetworkUrl`** to the returned **`url`**, clears local preview bytes/path, and autosave can persist **`coverImageUrl`**.  
- On failure: keeps **local preview** and shows an inline note that the cover is **not saved online** (snackbar carries **`MediaUploadException.userMessage`**).  
- **`storyBasicsRemoteCoverUrl`** centralizes which values become **`StoryBasics.coverImageUrl`**: only **http(s)** URLs — **never** raw filesystem paths.  
- Debounced autosave on creator basics now passes **`coverImageUrl`** from remote URL fields (fixes prior **`null`** cover on every autosave).

## Audio Upload Flow

- **`_AudioUpsertSheet`** takes **`uploadAudio`** and adds primary **`Upload to server`** ( **`FilledButton`** ) calling **`uploadAudioPlatformFile`** after file pick.  
- Success **`Navigator.pop`** returns **`sourceUrl`** = backend URL → **`setStoryAudio`** ( **`durationSeconds`** = server value or optional manual seconds).  
- **“Attach local file only (draft preview)”** remains secondary and explicitly **not** publish-ready.  
- Copy updated to describe server upload vs local-only.

## Auth Behavior

- Upload paths require a **non-empty Bearer** token from secure storage; otherwise a **SnackBar** prompts sign-in.  
- No use of **`DEV_OWNER_ID`** or dev-owner headers for upload.

## Error Handling

- **401**: **`notifyIfStrictUnauthorized401`** + user message **“Session expired. Please sign in again.”** (via **`MediaUploadException`**).  
- **400 / 413 / 415**: mapped to short, non-technical **`MediaUploadException.userMessage`** strings.  
- **Network / parse failures**: **“Could not reach the server…”** or generic retry message — **no raw stack traces** in UI strings.

## Tests Added

- **`media_upload_repository_test.dart`**: URL + **`Authorization`** header, JSON parsing, **413** / **415** / missing auth behavior.  
- **`story_basics_remote_cover_url_test.dart`**: remote URL vs filesystem path rules.  
- **`story_creator_public_audio_url_test.dart`**: **`StoryDraftMapper.fromDomainRemoteSafe`** preserves **http** localhost-style upload URLs (M5b-style path).

## Flutter Analyze Result

Command:

`flutter analyze` on the touched paths listed above.

Result: **No errors.** Remaining items are **infos** on existing **`DropdownButtonFormField.value`** deprecation in `create_story_basics_form.dart`, and a **warning** for an unused **`_buildStepPreviewCard`** helper that predates this work.

## Flutter Test Result

Commands:

- `flutter test test/features/create` — **passed** (all tests in that directory).  
- `flutter test` — **passed** (full suite).

## Remaining Risks

- **No upload progress %**: only a busy spinner; large audio files may feel frozen on slow networks.  
- **Token refresh**: upload uses the current access token only; expiry mid-upload relies on normal session / strict-401 handling.  
- **Web vs native**: audio upload uses **bytes** on web (**`withData: kIsWeb`** in file picker); very large files may stress memory.  
- **Analyze noise**: unrelated deprecations in the basics form remain until a separate Flutter upgrade pass.

## Recommended Next Step

**M5d / product**: Optionally surface upload progress ( **`StreamedRequest`** / chunked reporting not in backend today), and tighten creator QA around remote **`NIMON_USE_REMOTE_DRAFTS`** + signed-in flows for end-to-end validation.

---

### Checklist (execution summary)

| Question | Answer |
|----------|--------|
| Upload repository added? | **Yes** — `MediaUploadRepository` + provider |
| Cover picker uploads? | **Yes** — when signed in; `onCoverUpload` wired from **Create** + **Story basics** |
| Audio picker uploads? | **Yes** — **Upload to server** in Listening sheet |
| Returned URL saved to draft? | **Yes** — `coverImageUrl` / `setStoryAudio` with **http(s)** URL |
| Auth header sent? | **Yes** — via **`authHeaderBuilderProvider`** |
| Tests passed? | **Yes** — `test/features/create` + full **`flutter test`** |
| `flutter test` passed? | **Yes** |
| Remaining risks? | **See above** (progress, token edge cases, web memory) |
| Next step M5c? | **Done**; follow-up = UX hardening / remote E2E |
