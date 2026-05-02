# Nimon — Learn OFF → Publish → Back inactive-element assertion

Assertion:

> `element._lifecycleState == _ElementLifecycle.inactive`

Repro path (given):
1) Story sentences screen → edit sentences → RO ready  
2) Learn mode ON → open a learn module → return to sentences  
3) Learn mode OFF  
4) Tap Read Only Publish  
5) Immediately press top-left back  
6) Crash with inactive element assertion

## A) Exact root cause

**`performCreatorDrawerPublish()` was performing inherited lookups from the caller’s `BuildContext` (specifically `Theme.of(context)` and `ScaffoldMessenger.of(context)`) *after* awaiting the async publish.**

When the user hits back immediately after tapping Publish, the creator route can begin transitioning and the element becomes **inactive**. Even if `context.mounted` is still true briefly, those inherited lookups can trigger the framework assertion.

This is a **publish/back overlap** problem: the publish future completes “late” and tries to build/show UI feedback using a now-inactive element.

## B) Exact file + function

- `lib/features/create/creator_drawer_publish.dart`
  - `performCreatorDrawerPublish(...)`

## C) Bug category (what actually caused it)

- **Primary:** stale context / inherited lookup after async gap  
- **Specifically:** publish callback ordering + immediate back navigation overlap  
- **Not required to reproduce:** stale learn-mode state (Learn mode sequence increases likelihood of route swaps, but the crash is triggered by publish completing after back)

## D) Minimal safe fix

**Capture inherited dependencies synchronously before `await`, and use the captured values after the async publish instead of calling `Theme.of(context)` / `ScaffoldMessenger.of(context)` post-await.**

Implemented change:

- Capture:
  - `final messenger = ScaffoldMessenger.maybeOf(context);`
  - `final theme = Theme.of(context);` and derived `ColorScheme` + text styles
- After `await`, use `messenger?.showSnackBar(...)` and the captured styles.

This keeps user-visible behavior the same (same snackbar content and publish navigation), but removes the risky post-await inherited lookups.

## E) Nearby same-class risks (targeted)

These remain “same class” and could still bite if they run after a route swap:

- `lib/features/create/story_creator_sentences_screen.dart`
  - post-frame callbacks that call `GoRouterState.of(context)` inside debug strings
- `lib/features/create/creator_learn_mode_sync.dart`
  - non-router fallback path schedules post-frame `syncCreatorDrawerSessionFromContext(context, ref)` (now safer than before, but still relies on a potentially stale context for the fallback path)

