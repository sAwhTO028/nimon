# Creator Audio Upload Release UX Clarity Fix Report

**Report date:** 2026-05-05  
**Scope:** Flutter UI copy and success actions only. Backend, migrations, and `MediaUploadRepository` unchanged.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/creator_audio_upload_sheet.dart` | Pick: added helper *“Choose a file first, then save it to this story.”* Upload: added *“Please wait…”* under *Uploading…* (Cancel remains disabled). Success: explanatory line *“Tap Save audio to apply this file to your story draft.”* Primary CTA **Save audio** (replaces “Use this audio”, save icon). |
| `lib/features/create/story_creator_sentences_screen.dart` | Listening help dialog: step 3 and optional sections aligned with **Save audio** and post-upload **Optional details**. |
| `test/features/create/creator_audio_upload_sheet_test.dart` | Asserts helper on pick; success asserts **Save audio** + draft-apply line. |

## Root Cause

The release pick screen only offered **Choose audio file** and **Cancel**, so it was unclear that **choosing** uploads the file to storage while **a separate confirm** applies it to the draft. The success primary button said **Use this audio**, which did not read like persisting story audio.

## Empty State Copy

- **Title:** unchanged (`sheetTitle`, e.g. *Upload story audio*).
- **Body:** *Choose an audio file for this story.* / *Supported: mp3, m4a, wav*
- **Helper:** *Choose a file first, then save it to this story.*
- **Actions:** **Choose audio file** / **Cancel** (signed-out: disabled choose + sign-in line).

## Success State Actions

- Summary card still shows uploaded **filename** (and optional display name from fields).
- Instruction: *Tap Save audio to apply this file to your story draft.*
- **Save audio** — pops [`AudioUpsertResult`] and applies URL/metadata to the draft (same behavior as former “Use this audio”).
- **Replace audio** / **Remove audio** — unchanged.
- **Optional details** — collapsed expansion for display name / duration override (unchanged).

## Tests Updated

| Check | Coverage |
|-------|----------|
| Empty helper | `Choose a file first, then save it to this story.` |
| Release hides advanced | Public URL / attach still absent |
| Success | `FilledButton` **Save audio** + draft-apply sentence |
| Replace / Remove | Still present |

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/creator_audio_upload_sheet.dart \
  lib/features/create/story_creator_sentences_screen.dart \
  test/features/create/creator_audio_upload_sheet_test.dart
```

**Result:** No issues found.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/create` | **70** passed |
| `flutter test` | **231** passed |

## Remaining Risks

- Users may still need to **save the overall draft** elsewhere for remote persistence — copy refers to applying audio **to the draft model**, not global publish.
- Upload remains **indeterminate** progress (API limitation).

## Output Summary

| Question | Answer |
|----------|--------|
| **Save audio** after upload? | **Yes** (primary CTA, save icon) |
| Empty helper copy? | **Yes** — *Choose a file first, then save it to this story.* |
| Replace / Remove preserved? | **Yes** |
| `test/features/create` passed? | **Yes** (70) |
| Full `flutter test` passed? | **Yes** (231) |
