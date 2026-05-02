# Nimon Creator Flow — Final Stability Report (2026-04-23)

Scope: creator flow back/flush/reset/resume changes (Phases 2–5), and stabilization checks requested.

## Tooling / Verification Performed

- **Flutter**: `flutter --version` → Flutter 3.41.6 (Dart 3.11.4).
- **Static analysis**: `flutter analyze` (non-zero exit).
- **Widget/unit tests**: `flutter test` (non-zero exit; failures in creator test suites).
- **Code audit**: searched for creator entry channel usage, learn-hub remnants, GlobalKey usage, and common “unsafe context after await” patterns in the creator flow paths touched.

## Verification Checklist

### 1) Back behavior (all entry contexts)
- **PASS (code-level)**:
  - Centralized back path remains `handleCreatorBackPressed` in `lib/features/create/creator_back_policy.dart`.
  - Exit target routing still keyed off `creatorEntryChannelProvider` and is set by:
    - Add flow (`CreatorEntryChannel.add`)
    - Processing resume (`CreatorEntryChannel.processing`)
    - Published reopen (`CreatorEntryChannel.publishedReopen`)
    - More/Profile entry (`CreatorEntryChannel.shellMore`)
  - Back now enforces: **detect blocking → flush draft to Processing → reset ephemeral UI → exit**.
- **RISK**:
  - Publish-in-progress block is currently silent (returns without UI feedback). Policy-compliant, but could be perceived as “back didn’t work” if publish stalls.

### 2) Processing continue
- **PASS (code-level)**:
  - Resume path: `CreatorDraftResumeFlow.resumeFromProcessing` restores draft by id (`forceReloadFromDisk: true`) and routes to last meaningful section using stored resume meta.
  - Stored resume meta is refreshed on back flush and by route sync recorder.

### 3) Learn ON/OFF transitions
- **PASS (code-level)**:
  - Learn mode “OFF” normalization still routes away from learn surfaces to sentences main.
  - Resume now restores Learn mode meaningfully by inferring from persisted draft content and publish state.
- **RISK**:
  - Learn mode inference can be “sticky” if any learn content exists (intended), but there is no explicit persisted flag in V1.

### 4) module open → back
- **PASS (code-level)**:
  - Module navigation uses canonical `?panel=` on `/create/story/sentences` and back normalization flushes before leaving the panel.

### 5) publish flows
- **PASS (code-level)**:
  - Publish sets a shared `creatorPublishInProgressProvider` flag; back checks it and blocks exit until completion.

### 6) no stale creator subtree
- **PASS (code-level)**:
  - Route sync guard prevents continuing creator sync when not under `/create/story`.
  - Resume navigation avoids stacking duplicate story routes by using `go` when already inside the subtree.

### 7) no duplicate GlobalKey
- **PASS (spot-check)**:
  - Creator progress drawer already uses distinct subtree keys per host slot.
  - No new GlobalKeys added by these phases.

### 8) no lifecycle assertion
- **PASS (code-level)**:
  - Back policy and resume logic guard `context.mounted` after awaits where navigation occurs.
- **RISK**:
  - `flutter analyze` reports many unrelated warnings; lifecycle assertions are best validated by running an interactive smoke pass on device/emulator.

## “Check” Requirements

### Zero UNKNOWN entry context
- **PASS**: `CreatorEntryChannel` is an enum with no `unknown` value and call sites explicitly set it for creator entry/resume paths.

### No build-time side effects
- **PASS (creator flow)**:
  - Creator route sync is owned by `CreatorRouteSyncListener`, not by `build()`.
  - Draft loading is performed by route→session sync, not in widget build methods (as intended).

### No unsafe context usage after await
- **PASS (touched paths)**:
  - Back policy / resume / publish helpers consistently check `context.mounted` before navigation or UI operations after awaits.

## Analyzer Results (flutter analyze)

`flutter analyze` exited non-zero due to warnings/infos across the repo (examples include `include_file_not_found` for `flutter_lints`, unused imports, deprecated APIs). These are not creator-flow specific, but they currently prevent a clean analyze run.

## Test Results (flutter test)

`flutter test` exited non-zero with **creator-flow test failures**. Key failure pattern:

- Several creator tests assert older UI structures (e.g. looking for an `AlertDialog` where the UI uses a bottom sheet, or button type expectations).
- Failures observed in:
  - `test/create_shell_parent_child_flow_test.dart`
  - `test/creator_progress_drawer_module_switching_widget_test.dart`

These failures appear to be **test expectation drift** relative to the now-locked back/flush semantics and current UI composition, not compilation errors in the creator flow.

## Remaining Risks / Follow-ups

- **Stabilize tests**: update creator widget tests to match the actual UI surfaces (bottom sheets vs dialogs) and button widget types, and to align with locked back semantics dialogs (Stay/Retry/etc.).
- **Publish-back UX**: consider a minimal “Publishing…” blocker/snack to avoid perceived unresponsiveness while still blocking exit.
- **Learn mode persistence**: if future requirements demand explicit persistence, add a draft-level flag (out of scope for this pass).

