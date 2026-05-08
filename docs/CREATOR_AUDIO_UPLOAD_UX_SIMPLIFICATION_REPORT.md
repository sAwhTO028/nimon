# Creator Audio Upload UX Simplification Report

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/creator_audio_upload_sheet.dart` | **New.** Release-oriented bottom sheet: primary “Choose audio file” → upload with progress → success with “Use this audio” / “Replace audio” / “Remove audio”. “Optional details” and “Advanced options” are collapsed `ExpansionTile`s. |
| `lib/features/create/story_creator_audio_editor_screen.dart` | Wires `CreatorAudioUploadSheet`, pre-reads auth for `canUpload`, `AudioUpsertResult` + same `setStoryAudio` / `setStoryAudioFromPickedFile` paths. Main module: short copy, “Choose audio file” CTA, “Replace audio” / “Remove audio”, friendlier summary status. |
| `lib/features/create/story_creator_sentences_screen.dart` | Listening “how to” help dialog copy updated for the new flow. |
| `test/features/create/creator_audio_upload_sheet_test.dart` | **New.** Widget tests for empty CTA, advanced collapsed, signed-out, success state (debug hook). |
| `test/creator_progress_drawer_module_switching_widget_test.dart` | Finder: `Add audio` → `Choose audio file`. |
| `test/create_shell_parent_child_flow_test.dart` | Same finder update. |

Backend, DTOs, and repositories were not modified.

## UX Problems (Before)

- One sheet mixed **public URL**, **device upload**, and **local-only attach** with long technical copy.
- Users had to parse engineering language (remote save, `http(s)`, draft vs publish) before acting.
- Primary path (pick → upload) was not visually dominant.

## New Primary Flow

1. **Open sheet** — Title **“Upload story audio”** (or **“Replace audio”**). Short lines: *Choose an audio file for this story.* / *Supported: mp3, m4a, wav*
2. **Choose audio file** — File picker, then **uploading** with a **linear progress** bar and *Uploading…*
3. **Success** — **Upload complete**, file summary, **Use this audio** (pops and updates draft), **Replace audio** (return to step 1), **Remove audio** (close without saving)
4. **Optional details** (collapsed) — display name and duration, not on the first screen.
5. **Main Listening module** (no audio) — *No story audio yet* + **Choose audio file**; with audio — summary + **Replace audio** / **Remove audio**

## Advanced / Hidden Flows

- **Advanced options** (collapsed by default):
  - **Public audio URL** + **Save public URL** (unchanged API: `setStoryAudio` with validated `http`/`https`)
  - **Attach without uploading** + file pick (unchanged: `setStoryAudioFromPickedFile`)
- No debug-only flag was required: advanced paths remain available to staging/support without shipping a separate build.

## Signed-out Behavior

- `canUpload` is computed when the sheet opens (access token present / non-empty).
- If not signed in: *Sign in to upload audio and save it with your story.* and the **Choose audio file** button is **disabled** (lock icon). Snackbars for failed upload still use existing `MediaUploadRepository` messages when applicable.

## Tests Added

| Test | Intent |
|------|--------|
| `pick phase shows … Choose audio file` | Primary CTA and short copy |
| `Advanced options starts collapsed` | `Save public URL` not available until expand |
| `signed-out … disabled` | Friendly line + `onPressed == null` |
| `success state shows …` | `debugSuccessResponse` (debug/tests only) drives success UI |

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/creator_audio_upload_sheet.dart \
  lib/features/create/story_creator_audio_editor_screen.dart \
  lib/features/create/story_creator_sentences_screen.dart \
  test/features/create/creator_audio_upload_sheet_test.dart
```

**Result:** No issues found.

## Flutter Test Result

```bash
dart format <touched Dart files>
flutter test test/features/create
flutter test
```

**Results:** `test/features/create` — all passed; full suite — **222 tests passed** (run date: 2026-05-04).

## Remaining Risks

- **File picker / platform**: Same as M5c — large files on web still load into memory.
- **No percent progress** from the API: indeterminate bar only.
- **Two “Attach without uploading” labels** (section title + button) may still read slightly redundant; acceptable for clarity.

## Recommended Next Step

Product QA on **signed-in** remote drafts (`NIMON_USE_REMOTE_DRAFTS`): pick → upload → save draft → re-open story and confirm Listening still shows **Saved online** and playable URL. Optionally add integration coverage that mocks `FilePicker` + upload if CI needs end-to-end confidence.
