# M14H Profile Published Monos refresh and sticky sub-tab report

## Problem

1. **Published > Monos** lacked pull-to-refresh comparable to **Saved** (remote).
2. **Monos / Collections** pill row lived inside the Monos (and mock Collections) `ListView`, so it scrolled away; **remote Collections** already kept the row outside the list.

## Scope

- Flutter only: `lib/features/profile/profile_screen.dart` (`_FolderGroupList`), Published tab wiring, tests, and this report.
- No backend, header, top-level tabs, collection product rules, Saved remote tab (`ProfileSavedRemoteTab`), mono row data, menus, or trash policy changes.

## Refresh audit

See `docs/M14H_PROFILE_PUBLISHED_MONOS_REFRESH_STICKY_AUDIT.md` for the full table and comparisons.

## Published Monos refresh fix

- Added optional `onLooseListRefresh` to `_FolderGroupList`.
- Published tab passes `() => ref.read(profilePublishedMonoPagerProvider.notifier).refresh()` when `RemoteBackendConfig.useRemoteDrafts` is true.
- Wrapped the Monos scroll body in `RefreshIndicator` when `onLooseListRefresh != null`, with `ValueKey('profilePublishedMonosRefreshIndicator')` for Published.
- Used `AlwaysScrollableScrollPhysics` when refresh is enabled so pull-to-refresh works with short or empty lists.
- On failure, `ProfilePublishedMonoPager.refresh()` keeps prior items and sets `error` (existing notifier behavior); UI does not blank the list.

## Sticky sub-tab root cause

The filter row was `itemBuilder` index `0` inside `ListView.separated`, so it participated in scroll offset.

## Sticky sub-tab fix (Option A)

- **Monos**: `ColoredBox` → `Padding` → `Column` → `_publishedSubTabKeyIfNeeded(_buildFilterOrSelectionBar())` + `SizedBox(height: 4)` + `Expanded` → scrollables (`NotificationListener` → optional `RefreshIndicator` → `ListView`).
- **Mock collections** (inside `if (_filter == collections)` when not remote Published API path): same outer `Padding` + `Column` + `Expanded` + folder `ListView` only.
- **Remote Published collections**: unchanged structure; added `profilePublishedSubTabRow` key on filter and `profilePublishedCollectionsList` on the list.

## Scroll architecture

- Published tab page remains `PageView` child with bounded height from `Expanded` above; inner `Expanded` receives finite max height, so `ListView` + `RefreshIndicator` stay bounded.
- **M14H-2:** Bottom clearance for dock overlap uses **scroll-inside** padding (see below), not only outer `Padding` on the sticky `Column`.

## M14H-2 Bottom dock overlap regression fix

### Root cause

M14H moved the Monos / mock Collections `ListView` into `Column` + `Expanded` and set **`ListView` padding to zero**, while keeping bottom inset only on the **outer** `Padding` around the `Column`. With the shell `Scaffold(extendBody: true)` and `FloatingDockNavBar`, the **scroll extent** no longer included enough **bottom sliver padding inside the scroll view**. Shrinking the viewport with outer padding is not equivalent to `ListView` bottom padding: the last row could sit with its lower half in the dock overlap region without enough **scrollable** slack to pull it fully clear.

### Padding / clearance fix

- Added **`_profileFloatingDockScrollClearance(BuildContext)`** = `FloatingDockNavBar.dockOccupiedZoneHeight(context) + 12` (same geometry as Mono tab: `dockOuterBottomPad + viewPadding.bottom + dockPillHeight + air`).
- **`_FolderGroupListState._listBottomScrollClearance()`** = `max(_profileFloatingDockScrollClearance(context), widget.bottomPadding)` so we never go below the profile shell’s legacy `bottomNavHeight + padding.bottom + extraBottomPadding` passed from `ProfileScreen`.
- **Published Monos**, **mock Published collections** folder list, and **remote Published collections** list (plus loading/empty/error bodies): outer horizontal/top padding unchanged; **outer bottom** on those `Padding` wrappers set to **0**; **`ListView.separated` / placeholders** use `padding: EdgeInsets.only(bottom: _listBottomScrollClearance())` (or equivalent `Padding` around non-scroll centers).
- Sticky sub-tab architecture, `RefreshIndicator`, and keys are unchanged.

### Tests

- `test/features/profile/profile_published_monos_bottom_padding_test.dart`: `FloatingDockNavBar.dockOccupiedZoneHeight` matches injected `viewPadding`; no `FlutterError` overflow; sub-tab row stays fixed when dragging; when the list is scrollable, can scroll to end and last row clears the dock zone inside the list viewport; refresh indicator absent when remote drafts off.

### Manual result

Pending on device; follow M14H-2 Part E smoke (Published Monos scroll to last row, dock overlap, PTR, Collections switch, light/dark).

## Provider invalidations

- No new invalidation paths; reuse `profilePublishedMonoPagerProvider.notifier.refresh()` for PTR.
- Existing listeners (e.g. processing refresh bump → `refresh()`) unchanged.

## Tests added

- `test/features/profile/profile_published_sticky_subtab_test.dart`:
  - Refresh indicator present iff `RemoteBackendConfig.useRemoteDrafts`.
  - Sticky sub-tab dy stable vs list drag (with conditional row motion when `maxScrollExtent > 8`).
  - Mock Collections: key + drag + stable sub-tab.
  - Dark theme: sub-tab labels visible.
- `test/features/profile/profile_published_monos_bottom_padding_test.dart` (M14H-2).

## Commands run

```text
dart format lib/features/profile/profile_screen.dart test/features/profile/profile_published_sticky_subtab_test.dart test/features/profile/profile_published_monos_bottom_padding_test.dart
flutter analyze lib/features/profile/profile_screen.dart
flutter test test/features/profile
flutter test
```

- `flutter test test/features/profile` — passed.
- Full `flutter test` — one failure in `test/create_shell_parent_child_flow_test.dart` (Progress drawer / disabled `creator_progress_open_button`); unrelated to M14H profile layout. Re-run or fix that test separately if it blocks CI.

## Manual verification

Use Part G of the M14H spec on device/emulator, including `NIMON_USE_REMOTE_DRAFTS=true` for Published Monos pull-to-refresh.

## Remaining risks

- **Very short** vertical space (pathological constraints) with `Column` + `Expanded` could still stress layout; normal Profile `PageView` heights are sufficient on phones.
- **Widget-level** pull-to-refresh on Published Monos is only compiled in when `NIMON_USE_REMOTE_DRAFTS=true`; default test build asserts absence of refresh indicator.
