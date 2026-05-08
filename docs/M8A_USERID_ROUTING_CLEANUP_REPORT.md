# M8a UserId Routing Cleanup Report

## Files Changed

| File | Change |
|------|--------|
| `lib/features/profile/public_profile_routing_policy.dart` | **New.** Pure helpers for debug-only legacy `?creator=` vs release rejection. |
| `lib/features/profile/public_profile_screen.dart` | **Primary path:** `userId` → remote API only. **Legacy:** mock NestedScrollView only when `legacyDemoCreatorProfileActive` (debug + `?creator=`). **Release:** handle-only URL shows explanatory screen (no mock). DEV banner on mock profile. |
| `lib/features/profile/creator_profile_location.dart` | Documentation aligned with M8a policy; formatting only in logic. |
| `lib/features/profile/notifications_screen.dart` | `actorUserId` on `AppNotificationV1`; follow taps call `creatorProfileLocation` with **userId first** when set; mock list still uses handle-only for `n1` (no backend id). |
| `lib/features/profile/profile_screen.dart` | `_PublicProfilePreviewCard` → `ConsumerWidget`; **View public profile** pushes `/profile/public?from=owner&userId=<session>` when signed in. |
| `lib/main.dart` | Comment on `/profile/public` query params (`userId` canonical, `creator` legacy/mock). |
| `test/features/profile/public_profile_routing_policy_test.dart` | **New.** Unit tests with `isDebugMode` overrides (tests run in debug; overrides simulate release). |

## Call-site Matrix

| File | Route used | userId available? | Legacy handle allowed? | Action taken |
|------|------------|-------------------|------------------------|--------------|
| `mono_screen.dart` | `creatorProfileLocation(..., allowLegacyHandle: **false**)` | Yes (`MonoFeedItem.writerId`) when present | **No** | **Unchanged** — already canonical; missing id yields null + snackbar elsewhere (M7 policy). |
| `profile_connections_screen.dart` | `/profile/public?userId=<encoded>` | Yes (`MeFollowingUser.userId`) | N/A | **Verified OK** — production following list routes by userId only (already encoded). |
| `profile_screen.dart` (_PublicProfilePreviewCard) | `/profile/public?from=owner&userId=<id>` when authed; else `?from=owner` only | Yes when `AuthSessionAuthenticated` | N/A | **Updated** — signed-in users get canonical **userId** + remote owner preview. |
| `notifications_screen.dart` | `creatorProfileLocation(userId?, handle?, allowLegacyHandle: **true**)` | Optional (`actorUserId`); mock **n1** has **no** userId | **Yes** (fallback for mock follow row) | **Updated** — routing prefers userId when added to notifications later; follow notification still handle-only for mock data. |
| `main.dart` | Parses `userId`, `creator`, `from` | From URI | `creator` parsed | **Comment only** — router unchanged; screen gates mock by policy. |
| `public_profile_screen.dart` | Entry from router | From `userId` query | `creatorHandle` query | **Updated** — remote-first; mock fenced to debug + legacy helpers. |

## Routing Policy

1. **`/profile/public?userId=<uuid>`** is the **only** production path to a real creator profile (loads `RemotePublicCreatorProfileRepository`).
2. **`?creator=<handle>`** without `userId`:
   - **Debug (`kDebugMode`):** may show the **legacy mock** NestedScrollView (`legacyDemoCreatorProfileActive`).
   - **Release / profile:** **no mock** — `creatorHandleOnlyRouteRejectedOutsideDebug` shows a short explanation screen.
3. **No `userId` and no `creator`:** neutral empty-state copy pointing learners to Mono / profile preview.
4. **`creatorProfileLocation`:** always emits **`userId`** first when provided; handle route only if **`allowLegacyHandle`** is true (Mono uses **false**).

## Legacy Handle Handling

- Query parameter name remains **`creator`** for backward compatibility with bookmarks and deep links.
- UI copy on mock profile: **“DEV: Mock creator profile (?creator=). Shipped builds use ?userId=.”**
- Notifications mock (`New follower` / `@rina_travel`): **no stable `actorUserId`** in V1 seed data — routing keeps **`allowLegacyHandle: true`** so debug builds can open the mock profile; production notifications API should supply **`actorUserId`** when implemented.

## Tests Added

- `test/features/profile/public_profile_routing_policy_test.dart` — `legacyDemoCreatorProfileActive` and `creatorHandleOnlyRouteRejectedOutsideDebug` with explicit **`isDebugMode`** overrides so release-style behavior is asserted under test.

Existing:

- `test/features/profile/creator_profile_location_test.dart` — userId preference, `allowLegacyHandle` gating, null when empty.

## Flutter Analyze Result

- **Changed files (narrow scope):** `dart analyze` on `public_profile_screen.dart`, `public_profile_routing_policy.dart`, `creator_profile_location.dart`, `notifications_screen.dart`, `main.dart` → **No issues found.**

Note: `flutter analyze lib/features/profile/profile_screen.dart` still reports **pre-existing** warnings (unused fields, deprecated `withOpacity`, etc.); none were introduced for M8a aside from the preview card refactor.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/profile` | **PASS** |
| `flutter test test/features/mono` | **PASS** |
| `flutter test` (full suite) | **PASS** (322 tests) |

## Remaining Risks

- **Cold links** with only `?creator=` in **release** show the rejection screen — acceptable until marketing URLs are migrated to userId or a server resolver exists (M8 plan).
- **Guest “View public profile”** still pushes `?from=owner` without userId — shows generic empty state until sign-in (existing limitation).

## Recommended Next Step

Proceed to **M8b — Followers list backend + Flutter** (`docs/M8_DISCOVERY_AND_POLISH_PLAN.md`): paginated followers endpoint mirroring `GET /v1/me/following`, replace mock **`kV1ProfileFollowers`** on **`/profile/followers`**.
