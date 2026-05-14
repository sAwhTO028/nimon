# M14A Login Overflow and Published Edit Action Fix Report

## Problem

1. **Login (phone + keyboard):** With the keyboard open and a failed login message shown under the password field, the layout used a `Column` with `Spacer()` and no scroll. That produced a **RenderFlex overflow** (~2.8px and more on small devices).

2. **Profile > Workspace:** Rows in **“Editing • Previously published”** still exposed **Rename** and **Delete from this device** — wrong for published-edit **staging** (those actions are for true local drafts). Discarding edits must only remove the **draft/staging** row and must **never** trash the underlying published mono.

## Scope

- `lib/features/auth/login_screen.dart` — scroll-safe layout, keyboard padding, `resizeToAvoidBottomInset`.
- `lib/features/profile/profile_screen.dart` — workspace overflow menu + confirm discard flow + provider refresh.
- `lib/features/profile/workspace_draft_menu_policy.dart` — pure policy for menu entries.
- `lib/features/create/data/published_edit_staging_guard.dart` — guard for linked published-edit drafts.
- `lib/features/create/data/story_draft_repository.dart` + local/remote implementations — `discardPublishedEditStaging`.
- Tests and this report.

**Out of scope:** Auth validation rules, backend schema, published-mono trash APIs, publish lifecycle beyond discarding staging.

## Login Overflow Fix

- Replaced `Column` + `Spacer` with **`LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight: …)`** so content can scroll when `MediaQuery.viewInsets.bottom` grows with the keyboard.
- **`resizeToAvoidBottomInset: true`** on `Scaffold` (explicit).
- **`SafeArea`** with horizontal minimum padding; vertical padding comes from scroll padding + `viewInsets.bottom + 24`.
- **`keyboardDismissBehavior: onDrag`** on the scroll view.
- Preserved copy: **“Great!”**, subtitle, rounded card, **LOGIN**, **Guest >>**, **Create account**, Google stub; error text remains **below the password** field inside the card.

## Workspace Published Edit Policy

- **`workspaceDraftOverflowMenuActions`:**  
  - **Draft** (`effectiveDraftListWorkspaceState` → `draft`): **Rename**, **Delete from this device**.  
  - **Editing** (published-edit staging): **Cancel editing** only (single overflow item).

## Discard/Cancel Behavior

- Tapping **Cancel editing** opens a dialog: **“Cancel editing?”** with copy that the published story stays live; **Keep editing** vs **Discard changes** (destructive).
- On confirm, **`StoryDraftRepository.discardPublishedEditStaging(draftId)`**:
  - Loads the draft; requires **`publishState != draft`** and non-empty **`publishedMonoId`** (`isLinkedPublishedEditStagingDraft`).
  - Otherwise returns **`false`** (snackbar: cannot discard).
  - On success calls existing **`deleteDraft`** only (`DELETE /v1/story-drafts/:id` on remote; local clear) — **no** published-mono trash/delete/update routes.

## Providers Invalidated

After a successful discard:

- `storyCreatorDraftProvider` — `syncIfDraftWasRemovedExternally`
- `profileWorkspaceDraftPagerProvider` — **`refresh()`**
- **`bumpProfileCatalogSurfacesRefresh`** — bumps `profileProcessingListRefreshProvider` (Mono feed listens in `mono_screen.dart` when remote feed is enabled)
- `profilePublishedMonoPagerProvider` — **`refresh()`**

## Tests Added

| File | Purpose |
|------|--------|
| `test/auth/login_screen_overflow_test.dart` | Small viewport + `FakeViewPadding` keyboard inset + failed login; assert no overflow errors; LOGIN / Create account still present after `ensureVisible` + tap. |
| `test/features/profile/workspace_draft_menu_policy_test.dart` | Draft vs editing menu action lists. |
| `test/features/create/discard_published_edit_staging_test.dart` | Local discard true/false; remote HTTP is GET draft + DELETE story-drafts only (no `published-monos` path). |

## Commands Run

```bash
dart format lib/features/auth/login_screen.dart \
  lib/features/profile/profile_screen.dart \
  lib/features/profile/workspace_draft_menu_policy.dart \
  lib/features/create/data/published_edit_staging_guard.dart \
  lib/features/create/data/story_draft_repository.dart \
  lib/features/create/data/local_story_draft_repository.dart \
  lib/features/create/data/remote_story_draft_repository.dart \
  test/auth/login_screen_overflow_test.dart \
  test/features/profile/workspace_draft_menu_policy_test.dart \
  test/features/create/discard_published_edit_staging_test.dart

flutter test test/auth/login_screen_overflow_test.dart \
  test/features/profile/workspace_draft_menu_policy_test.dart \
  test/features/create/discard_published_edit_staging_test.dart

flutter test
```

Full suite: **532** tests, all passed (includes the new M14A tests).

**Backend:** Not changed; no `nimon-backend` commands required for M14A.

## Manual Verification

See plan **Part G** in product QA: phone keyboard + wrong password; workspace published-edit overflow → discard → published row still in **Published** tab and feed.

## Remaining Risks

- If a workspace row is marked **editing** but the full draft on disk **lacks** `publishedMonoId` (degraded/offline data), **`discardPublishedEditStaging` returns false** — user sees snackbar and no partial delete.
- Login test uses **simulated** insets (`FakeViewPadding`), not the IME; layout is still validated against the same `MediaQuery.viewInsetsOf` path the app uses.
