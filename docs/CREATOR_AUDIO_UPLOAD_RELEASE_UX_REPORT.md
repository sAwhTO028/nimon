# Creator Audio Upload Release UX Report

**Report date:** 2026-05-05  
**Scope:** Flutter creator Listening audio bottom sheet — release UI is **upload-only**; technical paths gated by compile-time flag. Backend, upload repository contracts, and DTOs unchanged.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/data/remote_backend_config.dart` | Added **`NIMON_CREATOR_AUDIO_ADVANCED`** (`creatorAudioAdvancedUxEnabled`) — default **false**. |
| `lib/features/create/creator_audio_upload_sheet.dart` | **Release pick screen:** title, subtitle, supported formats, **Choose audio file** only. Optional metadata + Public URL + attach-without-upload live under **`showAdvancedOptions`** (flag / tests). Removed duration prerequisite before upload. Signed-out copy shortened. **Cancel** disabled while **Uploading…**. Success path unchanged; optional details remain collapsed after upload. |
| `test/features/create/creator_audio_upload_sheet_test.dart` | Asserts release sheet hides URL, attach, optional/advanced labels; separate test with **`showAdvancedOptions: true`** covers collapsed advanced sections; signed-out copy updated. |

## Old UX Problems

- First screen mixed **Optional details**, **Advanced options**, **public URL**, and **local-only attach** with the primary file upload CTA.
- Pick flow required optional duration to be valid before upload could start (even when optional fields were collapsed).
- Advanced flows were always discoverable in production builds.

## New Upload-Only Flow

1. **Pick (release)** — `sheetTitle` (e.g. **Upload story audio**), *Choose an audio file for this story.*, *Supported: mp3, m4a, wav*, **Choose audio file**, **Cancel**.
2. **Uploading** — `LinearProgressIndicator`, *Uploading…*, **Cancel** disabled (no duplicate dismiss during upload).
3. **Success** — *Upload complete*, summary (filename, size, server duration when present), collapsed **Optional details** (display name / duration override), **Use this audio** / **Replace audio** / **Remove audio**, **Cancel**.

**Advanced / internal builds:** `--dart-define=NIMON_CREATOR_AUDIO_ADVANCED=true` or **`CreatorAudioUploadSheet(showAdvancedOptions: true)`** (tests) restores **Optional details** + **Advanced options** (public URL, attach without uploading) on the pick screen.

## Signed-out Behavior

- Copy: **Sign in to upload audio.**
- **Choose audio file** uses disabled **`FilledButton`** (lock icon); no URL or local workarounds on the release pick screen.

## Hidden / Removed Technical Paths

| Path | Release behavior |
|------|------------------|
| Public audio URL | Hidden unless advanced enabled |
| Attach without uploading | Hidden unless advanced enabled |
| Optional details on first screen | Hidden for release; optional fields after success remain |

## Tests Added

| Test | Intent |
|------|--------|
| `pick phase …` extended | No **Public audio URL**, **Attach without uploading**, **Optional details**, **Advanced options** in default build |
| `release sheet hides URL … advanced flag shows …` | With **`showAdvancedOptions: true`**, expand **Advanced options** → URL + attach actions appear |
| `signed-out …` | Short sign-in line + disabled primary button |
| `success state …` | Unchanged (debug success payload) |

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/creator_audio_upload_sheet.dart \
  lib/features/create/data/remote_backend_config.dart \
  test/features/create/creator_audio_upload_sheet_test.dart
```

**Result:** No issues found.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/create` | **70** passed |
| `flutter test` | **231** passed |

## Remaining Risks

- **No byte-level upload progress** from API — indeterminate bar only.
- **Internal QA** must pass **`NIMON_CREATOR_AUDIO_ADVANCED=true`** when validating URL / local-only flows.
- Very large files on web still follow existing **MediaUploadRepository** memory behavior (unchanged).

## Recommended Next Step

Product QA on signed-in **remote drafts**: pick → upload → **Use this audio** → save → reopen draft and confirm **Saved online** and playable URL.

## Output Summary

| Question | Answer |
|----------|--------|
| Upload-only flow for normal users? | **Yes** — pick → upload → success actions |
| Public URL hidden? | **Yes** unless **`NIMON_CREATOR_AUDIO_ADVANCED=true`** |
| Attach-without-upload hidden? | **Same** |
| Signed-out friendly? | **Yes** — short copy + disabled CTA |
| `test/features/create` passed? | **Yes** (70) |
| Full `flutter test` passed? | **Yes** (231) |
