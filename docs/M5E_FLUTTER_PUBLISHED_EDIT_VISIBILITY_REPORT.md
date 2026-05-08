# M5e Flutter Published Edit Visibility Report

## Files Changed

| Path | Change |
|------|--------|
| `lib/features/profile/data/published_mono_catalog_visibility_exception.dart` | **New** — `PublishedMonoHiddenWhileEditingException` and UI helpers for catalog detail errors. |
| `lib/features/profile/profile_processing_refresh.dart` | `bumpProfileCatalogSurfacesRefresh(ProviderContainer)`; doc note for M5e / Mono Home. |
| `lib/features/profile/data/remote_published_mono_repository.dart` | `GET /v1/published-monos/:id` **404** → `PublishedMonoHiddenWhileEditingException`. |
| `lib/features/mono/data/remote_mono_feed_repository.dart` | `GET /v1/mono/:id` **404** → same exception. |
| `lib/features/create/creator_resume_draft.dart` | After resume navigation, call `bumpProfileCatalogSurfacesRefresh` (Published + Processing entry + all `profileProcessingListRefreshProvider` listeners). |
| `lib/features/create/story_creator_provider.dart` | After successful `persistLocalNow` when `useRemoteDrafts` and draft is not pure `draft` publish state, bump profile processing refresh (triggers published/workspace/mono refresh). |
| `lib/features/mono/mono_screen.dart` | Listen to `profileProcessingListRefreshProvider`: clear remote detail cache + `monoFeedPagerProvider.refresh()` when remote For You feed is active. |
| `lib/features/profile/profile_screen.dart` | Published tab reader open: friendly snackbar on hidden-mono exception. |
| `lib/features/learn/*` (vocab, grammar, listening, quiz) | Catalog detail error panel uses `publishedMonoCatalogDetailErrorTitle` / `publishedMonoCatalogDetailErrorBody`. |
| `test/features/mono/remote_mono_feed_repository_test.dart` | 404 → exception. |
| `test/auth/remote_published_mono_repository_auth_test.dart` | Owner `get` 404 → exception. |
| `test/features/profile/published_mono_catalog_visibility_exception_test.dart` | Helper string tests. |

## Edit Refresh Behavior

- **Resume from Published / Processing:** `CreatorDraftResumeFlow.resume` and `resumeFromProcessing` call `bumpProfileCatalogSurfacesRefresh` after navigation so **Profile** (via existing `profile_screen` listener) refetches **Workspace** and **Published** lists.
- **Remote save on a published story:** `StoryCreatorDraftNotifier.persistLocalNow` bumps `profileProcessingListRefreshProvider` when `RemoteBackendConfig.useRemoteDrafts` and `publishState != draft`, so first/ongoing remote saves keep lists aligned with M5d.

## Workspace Editing Behavior

- Workspace data still comes from `GET /v1/story-drafts` workspace pager; no schema change. Refreshes above reload summaries so **editing** / `hasUnpublishedCoreChanges` appear after save.

## Published Tab Hide Behavior

- **List:** Backend omits hidden rows; refresh signals refetch `GET /v1/published-monos`.
- **Owner opening a row** (`RemotePublishedMonoRepository.get`): **404** maps to `PublishedMonoHiddenWhileEditingException` — **snackbar** with the same user message (not raw HTTP body).

## Mono Feed Refresh Behavior

- `MonoScreen` (when `useRemoteMonoFeed` + For You) subscribes to `profileProcessingListRefreshProvider` and runs **`refresh()`** on `monoFeedPagerProvider` plus clears in-memory detail hydration so the next view matches the API.

## Republish Restore Behavior

- **Read Only / Full Learn** publish paths already call `_bumpProfileProcessingListRefresh()` in `story_creator_provider` on success; that plus `persistLocalNow` bumps republish the same signal — **Workspace**, **Published**, and **Mono** listeners all run.

## Hidden Detail 404 UX

- **Message:** *"This story is being edited and will return after republish."* (via `PublishedMonoHiddenWhileEditingException` and helpers).
- **Surfaces:** public `GET /v1/mono/:id`, owner `GET /v1/published-monos/:id`, Learn catalog provider, Profile published reader open, Mono inline detail load.

## Tests Added

- `remote_mono_feed_repository_test`: 404 on `fetchMonoDetail`.
- `remote_published_mono_repository_auth_test`: 404 on `get`.
- `published_mono_catalog_visibility_exception_test`: title/body helpers.

## Flutter Analyze Result

```bash
flutter analyze lib/features/profile lib/features/mono lib/features/create lib/features/learn
```

**Result:** Completes with **issues** in those trees (pre-existing deprecations, unused members, etc.); **no new issues** were required to be fixed for M5e. Exit code may be **1** when the analyzer counts **warning**-level items.

## Flutter Test Result

| Suite | Result |
|-------|--------|
| `test/features/profile` + `test/features/mono` + `test/features/create` (targeted) | **Passed** |
| `flutter test` (full) | **Passed** (exit code **0**) |

## Remaining Risks

- **404 vs truly missing:** Any **404** on these two detail endpoints uses the “editing” copy; rare false positives if the server returns 404 for other reasons.
- **Refresh frequency:** Bumping on every `persistLocalNow` for published remote drafts may refetch lists often during active editing; acceptable for correctness; can throttle later.
- **Mono tab not mounted:** If the user never opens Mono Home, the listener is inactive until they open that route — next open still runs `loadFirstPage` / natural refresh.

## Recommended Next Step

**M5f (product):** Optional analytics on hidden-detail views; consider a single “Back to Workspace” CTA on learn error panels when the hidden exception is shown.

---

## Commands

```bash
dart format <touched files>
flutter analyze lib/features/profile lib/features/mono lib/features/create lib/features/learn
flutter test test/features/profile
flutter test test/features/mono
flutter test test/auth/remote_published_mono_repository_auth_test.dart
flutter test
```

## Output Summary

| Check | Result |
|-------|--------|
| Edit refresh wired? | Yes — resume + `persistLocalNow` (published remote) + existing publish bumps |
| Workspace editing visible? | Yes — refetch via same signal |
| Published tab hide aligned? | Yes — refetch + friendly owner open error |
| Mono feed refresh aligned? | Yes — `MonoScreen` listener |
| Republish restore refresh? | Yes — existing publish + `persistLocalNow` path |
| Hidden 404 friendly? | Yes — exception + learn/profile/mono copy |
| `flutter test` passed? | **Yes** (full suite) |
| Next step M5f? | See **Recommended Next Step** |
