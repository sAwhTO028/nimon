# M7e3c Public Profile Follow Smoke Report

## Entry Point Cleanup
Updated public creator profile navigation to **prefer `userId`** everywhere it is available, and to **avoid opening legacy/mock profiles** from real remote content when `writerId` is missing.

Key policy:
- Prefer `/profile/public?userId=<uuid>`
- Legacy `/profile/public?creator=<handle>` only for mock/demo surfaces
- If no usable identifier in a real surface: show “Creator profile is not available yet.”

## Routes
- Canonical:
  - `/profile/public?userId=<uuid>`
- Legacy (retained for mock/demo surfaces only):
  - `/profile/public?creator=<handle>`

## Manual Smoke Checklist
1. Login as **user A**
2. Publish a story as **user B**
3. As **user A**, open **Mono feed**
4. Tap creator name/avatar → **public profile opens via `userId`**
5. Tap **Follow**
   - followersCount increments
   - button becomes **Following**
6. Open Mono **Following** tab
   - creator’s stories appear (after refresh)
7. Open `/profile/following`
   - creator appears
8. From creator profile, tap **Following** (unfollow)
   - followersCount decrements
9. Confirm Mono **Following** feed no longer shows creator (after refresh)
10. Guest (signed out) opens a creator profile and taps **Follow**
   - snackbar: “Sign in to follow creators.”
11. Self profile:
   - Follow button is hidden

## Tests Added
- `test/features/profile/creator_profile_location_test.dart`

## Flutter Analyze Result
- `flutter analyze` on touched paths (PASS)

## Flutter Test Result
- `flutter test test/features/mono` (PASS)
- `flutter test test/features/profile` (PASS)
- `flutter test` (PASS)

## Remaining Legacy / Deferred
- Legacy handle route remains for mock/demo entry points (e.g. V1 notification mock actor handles).
- Full removal of legacy route can happen once all backend-sourced surfaces always provide `writerId`.

## Final Verdict
All real entry points now route creator profiles by `userId` when available, and missing `writerId` no longer silently opens a mock profile.

## Recommended Next Step
Proceed to a short **M7e3d smoke-only** milestone (or release checklist item) to run the manual checklist on real devices and confirm follow/unfollow refresh feels correct.

