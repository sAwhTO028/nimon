# Nimon — Flutter lifecycle assertion root cause

Assertion:

> `'package:flutter/src/widgets/framework.dart': Failed assertion: element._lifecycleState == _ElementLifecycle.inactive`

Goal: identify the concrete place a deactivated/inactive element is still being used (typically via `dependOnInheritedWidgetOfExactType` from a stale `BuildContext`).

## A) Most likely root cause

**A `BuildContext` is being used (via `GoRouterState.of(context)` / inherited lookups) after an `await` or in a post-frame callback, during a route transition where the widget’s element is already `inactive` even though `State.mounted` can still be true.**

This project has multiple “route sync” / “drawer publish” / “save then navigate” flows. The highest-signal offender is: **calling `GoRouterState.of(context)` after an async save completes**.

## B) Exact file/function (primary culprit)

### `lib/features/create/story_creator_sentences_screen.dart`

#### `_saveToDiskAndToast()`

This method does:

- `await ref.read(...).globalSaveDraftNow();`
- then (only checking `if (!mounted) return;`) calls:
  - `GoRouterState.of(context)` for debug/logging
  - `ScaffoldMessenger.of(context)` for UI feedback

`GoRouterState.of(context)` performs an inherited lookup, which will assert if `context` belongs to an element that has been **deactivated** (inactive lifecycle) during/after navigation.

Concrete snippet (see around the following lines in the file):

- `await ...globalSaveDraftNow();` then
- `final st = GoRouterState.of(context);` inside a `try { ... }` block

This matches the exact class of crash: context is “still mounted” but the element is already inactive because the route swapped (e.g. `context.go`, `context.pop`, drawer-close + navigation, publish flow navigation).

## C) Secondary likely culprit (same assertion class)

### `lib/features/create/creator_route_sync.dart`

#### `syncCreatorDrawerSessionFromContext(BuildContext context, WidgetRef ref)`

Inside a `WidgetsBinding.instance.addPostFrameCallback`, it does:

- `if (!context.mounted) return;`
- **`final gs = GoRouterState.of(context);`**

This is explicitly risky because post-frame callbacks frequently run *after* route transitions; in those moments the element can be **inactive**.

Notably, the same file already documents the exact issue:

- “caller’s `BuildContext` may already be `ElementLifecycle.inactive` while `State.mounted` is still true.”

…but the fallback `GoRouterState.of(context)` path still exists and can still be reached and crash.

## D) Why it triggers this assertion (mechanism)

The failing assertion happens when Flutter detects an inherited lookup or element operation being performed while the element is in an **inactive** lifecycle state.

In this codebase, the trigger is most plausibly:

- an async flow (`await` save/publish/load)
- plus navigation (`context.go` / `context.pop` / closing drawer + route change)
- then a callback continues and attempts to access `GoRouterState.of(context)` or other inherited lookups (`Theme.of`, `ScaffoldMessenger.of`, etc.) using the stale `context`.

`mounted`/`context.mounted` is **not always sufficient** to avoid this, because the element can become inactive during transitions while still being “mounted enough” for that boolean to remain true briefly.

## E) Minimum safe fix direction (no redesign)

### Fix pattern: capture router *before* the await / route change; never call `GoRouterState.of(context)` after.

For `StoryCreatorSentencesScreen._saveToDiskAndToast()`:

- Capture:
  - `final router = GoRouter.maybeOf(context);`
  - (and/or the `Uri` you need) **before** the `await`.
- After `await`, avoid `GoRouterState.of(context)` entirely.
- Use `router?.state.uri` / `router?.state.matchedLocation` for debugging, and keep `ScaffoldMessenger` usage guarded by `if (!mounted) return;`.

For `syncCreatorDrawerSessionFromContext()`:

- Remove/avoid the `GoRouterState.of(context)` calls inside post-frame.
- Prefer `GoRouter.maybeOf(context)` captured **synchronously** before scheduling the post-frame callback, then call `syncCreatorDrawerSessionForRouter(router, ref)` inside the callback.

This is the minimal change that directly targets the assertion without refactoring UI or architecture.

## F) Other nearby risky spots (watch list)

These aren’t proven crashes yet, but they share the same pattern and should be inspected if the assertion persists:

- `lib/features/create/story_creator_sentences_screen.dart`
  - `initState()` / `didChangeDependencies()` post-frame callbacks that call `syncCreatorDrawerSessionFromContext(context, ref)` and/or reference `GoRouterState.of(context)` in debug strings inside callbacks.
- `lib/features/create/creator_learn_mode_sync.dart`
  - `applyCreatorLearnMode()` does `context.go(...)` and then schedules a post-frame sync. It already prefers router-based syncing when available, but any remaining “context-based” post-frame sync is a candidate.
- `lib/features/create/creator_drawer_publish.dart`
  - publish flow schedules post-frame navigation. It already uses `router` when available and checks `context.mounted` in the context-based branch; if any other callback reads inherited state from `context` after navigation, it can reproduce the assertion.

