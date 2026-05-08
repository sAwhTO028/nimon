# Creator Listening Audio URL Fix Report

**Report date:** 2026-05-03  
**Scope:** Stop creator story audio from **disappearing after remote save** by making **public http(s) URLs** the supported path that survives **`StoryDraftMapper.fromDomainRemoteSafe`** and aligns with **M4b3d** reader policy. **No** backend, migrations, upload pipeline, or reader changes.

**Reference:** [CREATOR_LISTENING_ADD_AUDIO_AUDIT.md](CREATOR_LISTENING_ADD_AUDIO_AUDIT.md), [M4B3D_LISTENING_HYDRATION_REPORT.md](M4B3D_LISTENING_HYDRATION_REPORT.md).

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/story_creator_public_audio_url.dart` | **New.** `isPublicHttpAudioSourceUrl`, `publicAudioSourceUrlValidationMessage` (shared with notifier + UI). |
| `lib/features/create/story_creator_provider.dart` | **`setStoryAudio`** rejects non-http(s) URLs via **`isPublicHttpAudioSourceUrl`** (no silent accept of arbitrary strings). |
| `lib/features/create/story_creator_audio_editor_screen.dart` | Add/edit sheet: **public URL** field + **Save public URL**; shared display name + duration; **local file** section with warning + **Attach local file only**; result routes to **`setStoryAudio`** vs **`setStoryAudioFromPickedFile`**; module copy + empty state + summary card for URL vs local; main CTA **Add audio**. |
| `lib/features/create/story_creator_sentences_screen.dart` | Listening “how to” copy updated for URL-first; removed unused **`creator_quiz_ui_state`** import (analyzer hygiene). |
| `test/create_shell_parent_child_flow_test.dart` | Finder text **`Upload audio`** → **`Add audio`**. |
| `test/creator_progress_drawer_module_switching_widget_test.dart` | Same finder update. |
| `test/features/create/story_creator_public_audio_url_test.dart` | **New.** URL validation + **`fromDomainRemoteSafe`** / **`toDomain`** expectations. |

---

## Root Cause

Local file attach stored **non-http `sourceUrl`** and **local metadata**. **`RemoteStoryDraftRepository.saveDraft`** uses **`fromDomainRemoteSafe`**, which strips those fields; **`toDomain(putDto)`** then replaced the draft with a payload where **`storyAudio.isValidV1`** was often **false**, so the Listening UI looked empty.

---

## URL Input Behavior

- Bottom sheet **Public audio URL** `TextField` + **Save public URL** (primary).
- Validation message: **“Enter a valid http(s) audio URL.”** for empty / **`file://`** / **`local://`** / **`ftp://`** / other non-http(s) schemes (case-insensitive **http** / **https** allowed).
- **Display name** and **duration** optional, shared with local path.
- **Replace** sheet pre-fills URL when existing asset **`hasUploadedSourceUrl`**.

---

## File Picker Policy

- **Secondary** block **“Local file (draft only)”** with explicit copy: not synced for readers, usually lost after remote save; prefer public URL.
- **Attach local file only** requires a picked file; still calls **`setStoryAudioFromPickedFile`** for draft-only / preview use — **not** presented as publish-ready.

---

## Remote Save Behavior

Unchanged pipeline: **`fromDomainRemoteSafe`** + PUT + **`toDomain(putDto)`**. With **https (or http) `sourceUrl`**, **`_remoteSourceUrl`** keeps the URL on the wire DTO, so the post-PUT domain model still satisfies **`isValidV1`** and **`hasUploadedSourceUrl`**.

---

## Tests Added

| File | Coverage |
|------|------------|
| `test/features/create/story_creator_public_audio_url_test.dart` | Validation accepts **http/https**; rejects empty / **file** / **local** / **ftp**; remote-safe mapper preserves **https** and strips local-only; **`toDomain`** after remote-safe keeps **`isValidV1`**. |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/story_creator_audio_editor_screen.dart \
  lib/features/create/story_creator_provider.dart \
  lib/features/create/story_creator_public_audio_url.dart \
  lib/features/create/story_creator_sentences_screen.dart \
  test/features/create/story_creator_public_audio_url_test.dart
```

**Result:** No issues found (after removing redundant import in **`story_creator_sentences_screen.dart`**).

---

## Flutter Test Result

```bash
dart format <touched Dart files>
flutter test test/features/create
flutter test
```

**Results (2026-05-03 run):** `test/features/create` — **43** passed; full suite — **190** passed.

---

## Remaining Risks

- **Creators must host** audio at a reachable **http(s)** URL (CORS / TLS / hotlinking) — same as reader **M4b3d** constraints.
- **Local attach** still does not survive remote round-trip meaningfully; users may ignore the warning.
- **No URL linter** for reachability or MIME type — only scheme + trim.

---

## Recommended Next Step

**Upload pipeline** (signed PUT + persist **https** `sourceUrl`) or **mono-owned CDN** integration — out of scope for this V1 URL-only fix.
