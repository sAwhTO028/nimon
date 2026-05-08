# Creator Cover Upload UX Simplification Report

## Files Changed

| File | Change |
|------|--------|
| `lib/features/create/create_story_basics_form.dart` | Cover card redesigned: **Upload a cover image**, **Supported: JPG, PNG, WebP**, **Choose cover image** CTA, **LinearProgressIndicator** + *Uploading…* while uploading, **Saved online** + **Replace cover** when remote URL is set, **Local preview only** chip + short failure line on failed upload, **Remove cover** tooltip. New `coverUploadAllowed` (default `true`). |
| `lib/features/create/create_screen.dart` | Passes `coverUploadAllowed` from `authSessionProvider` (`AuthSessionAuthenticated`); snackbar for missing auth aligned to cover copy. |
| `lib/features/create/story_creator_basics_screen.dart` | Same as Create screen. |
| `lib/features/create/story_basics_cover_upload_outcome.dart` | Shorter `coverUploadFailureInlineHint` messages; generic failures → **Upload failed. Try again.** |
| `test/features/create/story_basics_cover_upload_outcome_test.dart` | Updated expectations for new hint strings. |
| `test/features/create/create_story_basics_form_cover_test.dart` | **New** widget tests: empty CTA, signed-out, remote **Saved online**. |

Backend, migrations, and `storyBasicsRemoteCoverUrl` / autosave merge logic were not changed (only user-facing copy and layout).

## UX Problems (Before)

- Long “not saved online / local preview” copy appeared even when the user was simply on an empty form.
- Mix of “tap thumbnail” instructions and technical merge behavior.
- No clear “saved” vs “local only” state at a glance.

## New Primary Flow

1. **Empty** — Short title + supported formats; **Choose cover image** (and tappable placeholder thumbnail when allowed).
2. **Uploading** — Full-width **linear** progress + *Uploading…* (spinner on thumbnail removed in favor of global progress line).
3. **Success (remote URL)** — **Saved online** with check-style icon, **Replace cover** text action, **Remove cover** (X) on the thumbnail.
4. **Remove** — Clears cover and preserves explicit-clear semantics for autosave (unchanged).
5. **No remote upload** (`onCoverUpload` null) — Local pick only; one line: **Local preview only.** when applicable.

## Signed-out Behavior

- `coverUploadAllowed` is `ref.watch(authSessionProvider) is AuthSessionAuthenticated` on **Create** and **Story creator** basics.
- If not authenticated: **Sign in to upload cover images.** in the card; **Choose cover image** is disabled; gallery is not opened from the CTA; snackbar uses the same message if upload is somehow attempted.
- SnackBar when the repository rejects upload without session: **Sign in to upload cover images.** (aligned with the card).

## Local Preview / Failure Behavior

- **Local-only** (no `http` URL on the form): a visible **Local preview only** chip; no “saved online” wording.
- **After failed upload** (outcome not success): same chip plus a **short** second line from `coverUploadFailureInlineHint` (e.g. **Upload failed. Try again.**, or size/type-specific text). No long multi-sentence “not saved online” paragraphs on success or empty state.
- Generic / network / 400 errors map to **Upload failed. Try again.** so copy stays consistent with the product ask.

## Tests Added

| File | Coverage |
|------|----------|
| `create_story_basics_form_cover_test.dart` | Empty: **Choose cover image** + supported line; signed-out: message + disabled button; draft with `https` cover: **Saved online** + **Replace cover**. |
| `story_basics_cover_upload_outcome_test.dart` | Updated: network → **Upload failed. Try again.**; 415 assertion uses **supported**. |

`story_basics_remote_cover_url_test.dart` and other autosave tests were re-run unchanged.

## Flutter Analyze Result

```bash
flutter analyze lib/features/create/create_story_basics_form.dart \
  lib/features/create/create_screen.dart \
  lib/features/create/story_creator_basics_screen.dart \
  lib/features/create/story_basics_cover_upload_outcome.dart \
  test/features/create/story_basics_cover_upload_outcome_test.dart \
  test/features/create/create_story_basics_form_cover_test.dart
```

**Result:** No errors. Pre-existing **info** on `DropdownButtonFormField.value` deprecation and **warning** on unused `_buildStepPreviewCard` in `create_story_basics_form.dart` (unchanged in this task).

## Flutter Test Result

```bash
dart format <touched Dart files>
flutter test test/features/create
flutter test
```

**Results (2026-05-04):** `test/features/create` — **70** passed; full suite — **225** passed.

## Remaining Risks

- **Session edge:** If the session flips to signed-out while a remote cover URL is still shown, the UI may still show **Saved online** until the user refreshes the draft; rare and unchanged by this UX pass.
- **Widget test:** End-to-end “failed upload → local chip + short error” is not fully simulated (would require `ImagePicker` / upload injection); inline hint behavior is covered in **unit** tests.

## Recommended Next Step

Light **QA** on device: sign in → **Choose cover image** → confirm **Saved online** after success; sign out → confirm disabled CTA and copy; force a 413/415 in staging → confirm short error + **Local preview only** without scary long text.
