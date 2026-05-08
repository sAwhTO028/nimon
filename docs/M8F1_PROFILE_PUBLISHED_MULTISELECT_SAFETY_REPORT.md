# M8f1 Profile Published Multiselect Safety Report

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/profile/profile_screen.dart` | Removed Published loose bulk delete; **Add to collection** placeholder + snackbar; aligned overflow **Add to collection** snackbar copy; deferred workspace pager `loadFirstPage` to next frame (Riverpod-safe); minor border color deprecation fix in the selection bar. |
| `test/features/profile/profile_published_multiselect_m8f1_test.dart` | New widget tests for Published vs Saved multiselect bars. |

---

## Product Decision Applied

- **Profile → Published → Monos** multiselect primary action is no longer bulk **Delete**.
- It is **Add to collection**, which shows **`Collections are coming soon.`** until backend APIs exist (`docs/M8F_CREATOR_COLLECTIONS_PLAN.md`).
- **Saved** tab multiselect **Unsave** is unchanged (mock Saved tab path).
- Per-item removal/trash flows were not redesigned here.

---

## Published Multiselect Behavior

- **Monos** filter + multiselect: toolbar shows **`N selected`**, **Cancel**, **`Add to collection`** (enabled when count > 0).
- Tap **Add to collection**: floating snackbar **`Collections are coming soon.`**, then selection clears and multiselect exits (same exit pattern as before).
- Row overflow sheet → **Add to collection** (single-story path): snackbar **`Collections are coming soon.`** (same message).
- **`onBulkDeleteLoose` removed**: no code path removes multiple Published loose rows from the pager or mock list via this toolbar.

---

## Saved Multiselect Behavior

- **Saved** section (`isSavedSection: true`) keeps **`Unsave`** on the multiselect **`FilledButton`** and **`onBulkUnsaveLoose`** for mock loose items.
- **Note:** With **`NIMON_USE_REMOTE_DRAFTS=true`**, the Saved tab uses **`_ProfileSavedRemoteTab`** (flat remote bookmarks), not **`_FolderGroupList`**; this report’s Saved widget test uses the **mock** Saved tab (`remote drafts off`), which is where **`Unsave`** bulk existed.

---

## Trash / Delete Flow Preservation

- **Published loose detail sheet** (`_showUploadedLooseItemSheet`): unchanged — still includes per-row actions as before (mock label **Delete** for non-remote items; remote/backend paths unchanged).
- **Mono reader** story options **Move to Trash** / permanent delete: unchanged; still covered by **`test/features/mono/mono_story_options_trash_test.dart`**.
- **Trash screen** / Workspace draft multiselect **Delete**: untouched.

---

## Tests Added

`test/features/profile/profile_published_multiselect_m8f1_test.dart`

1. **Published:** long-press loose mock row → **Multi Select** → asserts no **`FilledButton`** labeled **Delete**, **`Add to collection`** present → tap → **`Collections are coming soon.`**
2. **Saved:** **`initialTabIndex: 2`** → loose mock row multiselect → **`Unsave`** present, **no** **`Add to collection`**.

**Supporting change:** **`ProfileScreen.initState`** now schedules **`profileWorkspaceDraftPagerProvider.notifier.loadFirstPage()`** in **`WidgetsBinding.instance.addPostFrameCallback`**, avoiding Riverpod’s “modify provider during build” assertion when **`ProfileScreen`** is mounted under tests (and aligning cold-load timing with the deferred Published pager load).

---

## Flutter Analyze Result

Command:

```bash
flutter analyze lib/features/profile/profile_screen.dart test/features/profile/profile_published_multiselect_m8f1_test.dart
```

**Exit code:** `1` (analyzer reports **warnings** / **info** across `profile_screen.dart`, including pre-existing unused elements and many `withOpacity` deprecation infos).

**New/edited hotspot:** selection bar border uses **`Colors.black.withValues(alpha: 0.06)`** (no deprecation info on that line).

No analyzer **errors** were reported for the new test file.

---

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/profile/profile_published_multiselect_m8f1_test.dart` | **Pass** (2 tests) |
| `flutter test test/features/profile` | **Pass** (**85** tests) |
| `flutter test` | **Pass** (**356** tests) |

---

## Remaining Risks

- **Remote Published list + multiselect:** Bulk delete was already unsafe/incomplete as a removal mechanism; removing it avoids accidental client-only pager drops. Future **Add to collection** must call real APIs.
- **Cold open timing:** Workspace pager loads **one frame later** than before; negligible UX risk; avoids Riverpod lifecycle violations.
- **Saved remote tab:** Bulk **Unsave** for **`_ProfileSavedRemoteTab`** was out of scope for this toolbar (different widget tree).

---

## Recommended Next Step

**M8f2 — Backend creator collections:** Prisma models + NestJS routes per **`docs/M8F_CREATOR_COLLECTIONS_PLAN.md`** §4–5 (`CreatorMonoCollection`, owner/public APIs). Then replace the snackbar with real **Add to collection** UX (**M8f3**).

---

## Output Summary

| Question | Answer |
|----------|--------|
| Bulk delete removed from Published multiselect? | **Yes** (no **`Delete`** bulk button; **`onBulkDeleteLoose` removed**). |
| Add to collection placeholder added? | **Yes** — **`Collections are coming soon.`** |
| Saved Unsave preserved? | **Yes** (mock **`_FolderGroupList`** Saved path). |
| Per-item trash preserved? | **Yes** (no edits to **`mono_story_options_sheet.dart`**; trash tests still pass). |
| `test/features/profile` passed? | **Yes** (85). |
| Full `flutter test` passed? | **Yes** (356). |
| Next step | **M8f2** backend creator collections + migration when scheduled. |
