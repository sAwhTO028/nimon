# M8f8 Collection Remove And Bookmark Policy Report

## Scope
- Flutter-only UX adjustment for owner collection remove.
- Hide Save/Bookmark for own published mono content while preserving Save/Bookmark for other creators.
- No backend changes (unless ownership fields were missing; not needed).

## Collection Remove UX
- Owner collection detail 3-dot menu no longer removes immediately.
- Tapping the 3-dot now opens a bottom sheet with a single action:
  - **Remove from collection**
- Only after tapping **Remove from collection** do we call:
  - `DELETE /v1/me/creator-collections/:id/items/:publishedMonoId`
- On success: snackbar + refresh collection detail + refresh owner collections provider.
- Public collection detail remains view-only (no remove menu).

## Bookmark Ownership Policy
Product rule:
- If `currentUserId == monoOwnerId`, hide Save/Bookmark actions.
- Otherwise, keep existing Save/Bookmark behavior.
- If current user or owner is unknown, keep existing UX (do not hide).

Implementation:
- Introduced `canBookmarkMono()` helper.
- In `MonoScreen`:
  - Save/Bookmark rail slot is removed for own content.
  - `_toggleBookmark` is guarded as a safety net.

## Files Changed
- `lib/features/profile/owner_creator_collection_detail_screen.dart`
- `lib/features/mono/bookmark_ownership_policy.dart` (new)
- `lib/features/mono/mono_screen.dart`
- `test/features/profile/owner_creator_collection_detail_screen_test.dart`
- `test/features/mono/bookmark_ownership_policy_test.dart` (new)
- `docs/M8F8_COLLECTION_REMOVE_AND_BOOKMARK_POLICY_REPORT.md` (new)

## Tests Added
- Owner collection detail:
  - tapping 3-dot shows "Remove from collection"
  - delete call only occurs after tapping the menu item
- Bookmark policy:
  - unit tests for `canBookmarkMono`

## Commands Run
- `dart format` (touched files)
- `flutter test test/features/profile`
- `flutter test test/features/mono`
- `flutter test`

## Manual Verification
- Owner collection detail:
  - tap 3-dot -> sheet appears -> tap "Remove from collection" -> removal happens
- Mono reader:
  - own content: no "Save" rail action
  - other creator: "Save" rail action still present

## Remaining Risks
- Any other Save/Bookmark entry points outside `MonoScreen` may need the same gating if added later.

