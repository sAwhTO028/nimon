# Story Basics Upload And Autosave Fix Report

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/create/story_basics_cover_upload_outcome.dart` | **New:** upload outcome type + `coverUploadFailureInlineHint()` |
| `lib/features/create/story_basics_remote_cover_url.dart` | Added `storyBasicsPersistedCoverUrl()` for autosafe merge |
| `lib/features/create/create_story_basics_form.dart` | Seed-before-notify, suppress autosave during seed, cover clear flag, upload outcome handling |
| `lib/features/create/story_creator_basics_screen.dart` | Outcome-based upload, merged cover + preserved `promptSourceNote` on autosave |
| `lib/features/create/create_screen.dart` | Upload returns `StoryBasicsCoverUploadOutcome` + inline hints |
| `test/features/create/story_basics_remote_cover_url_test.dart` | Tests for `storyBasicsPersistedCoverUrl` |
| `test/features/create/story_basics_cover_upload_outcome_test.dart` | **New:** inline hint mapping tests |

## Root Cause

1. **Misleading cover message:** `onCoverUpload` returned `null` for every failure (including “not signed in”, network, and payload errors). The form always showed the same generic **“Not saved online yet… Sign in…”** line even when the user **was** signed in or when the failure was **network / file size / MIME** — and it duplicated messaging already shown in a `SnackBar`.

2. **Dropdowns / “In progress” regression:** `TextEditingController` listeners run **while** `_seedFromDraft` assigned fields **one-by-one**. `_notifyDraftFieldsChanged` ran **before** `_seedSnapshot` matched the full draft, so **`isDirty` became true** and debounced autosave wrote **partially empty** basics (e.g. missing level/category/duration), overwriting stored values and **completion / workspace state**.

3. **Cover + prompt wiped on autosave:** Debounced save passed **`promptSourceNote: ''`**, clearing stored notes. It passed **`coverImageUrl`** only from the form’s remote fields; before hydration or after local-only pick, **`null`** cleared **`StoryBasics.coverImageUrl`** because **`replaceCoverImage: true`** in the notifier.

## Cover Upload Message Fix

- Introduced **`StoryBasicsCoverUploadOutcome`** (`ok` / `pendingLocal` with optional **`inlineHint`**).
- **Not signed in:** `SnackBar` only; **`inlineHint: null`** (no redundant “sign in” line under the thumbnail).
- **`MediaUploadException`:** `SnackBar` keeps **`e.userMessage`**; **`coverUploadFailureInlineHint(e)`** maps **network**, **413**, **415**, **400**, etc., and returns **`null`** for sign-in / session-style copy so inline text does not contradict the snackbar.

## Dropdown Restore Fix

- **`_seedFromDraft`** now builds **`_seedSnapshot` from the draft first**, then assigns controllers and dropdowns under **`_suppressDraftNotifications`** so **no autosave runs mid-seed**.
- **`didUpdateWidget`** re-seeds when the draft **id** changes (reload / switch draft).

## No-op Back / Autosave Fix

- While **`_suppressDraftNotifications`** is true, **`onDraftFieldsChanged` is not called** — no bogus **dirty** during hydration.
- After seed, **`isDirty` is false** until the user actually edits — backing out without edits does not enqueue a debounced save that overwrites basics.

## Autosave Preservation

- **`storyBasicsPersistedCoverUrl`**: merges **draft `coverImageUrl`** when the form has not published a new http(s) URL, unless **`coverExplicitlyCleared`** (user tapped **clear** on the thumbnail).
- **`_coverExplicitlyCleared`** is set only in **`_clearCover`**, reset on successful upload or new pick.
- Debounced autosave uses **`draft.promptSourceNote`** instead of **`''`**, so module / completion metadata tied to that field is not wiped.

## Tests Added

- **`storyBasicsPersistedCoverUrl`**: preserve draft URL, prefer new URL, respect explicit clear.
- **`coverUploadFailureInlineHint`**: sign-in/session → no inline hint; network / 413 / 415 behavior.

## Flutter Analyze Result

Command: `flutter analyze` on the modified paths.

Result: **No errors.** Same pre-existing **infos** on `DropdownButtonFormField.value` deprecation and unused **`_buildStepPreviewCard`** in `create_story_basics_form.dart`.

## Flutter Test Result

- `flutter test test/features/create` — **passed**
- `flutter test` — **passed** (full suite)

## Remaining Risks

- **Multi-tab / concurrent edit:** Same draft edited elsewhere is not merged; re-seed is id-only.
- **Extreme edge:** If a future code path sets **`coverExplicitlyCleared`** incorrectly, cover could persist when the user meant to clear — mitigated by only setting the flag in **`_clearCover`**.

## Manual Verification Steps

1. **Signed in + backend up:** Pick cover → image uploads → thumbnail uses returned URL; **no** generic “sign in” line if upload succeeds.
2. **Signed in + backend down:** Pick cover → snackbar network message → optional inline “Could not reach server…” only (no “sign in”).
3. **Signed out:** Pick cover → snackbar “Sign in…” → **no** redundant inline sign-in paragraph.
4. Open **Story basics** on a **complete** draft → **Level / Category / Duration** match draft → back **without editing** → completion / workspace row unchanged.
5. Open basics, **edit title only** → debounced save runs → **cover URL** and **dropdowns** unchanged in storage unless edited.

---

### Output summary

| Question | Answer |
|----------|--------|
| Upload message fixed? | **Yes** — outcome + `coverUploadFailureInlineHint` |
| Dropdown values restored? | **Yes** — seed ordering + suppress during seed |
| No-op back preserves Complete status? | **Yes** — no spurious dirty / autosave during hydration |
| Autosave preserves `coverImageUrl`? | **Yes** — `storyBasicsPersistedCoverUrl` + explicit clear flag |
| Tests passed? | **Yes** — `test/features/create` |
| `flutter test` passed? | **Yes** — full suite |
