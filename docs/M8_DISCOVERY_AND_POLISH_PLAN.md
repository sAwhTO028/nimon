# M8 Discovery And Polish Plan

## 1. Executive Summary

M7 closed with full **bookmark/react**, **Saved**, **share link** copy UX, **follow/following** (including **Following** feed and **me following** list), **public creator profile** (`userId` route + writer feed), and a **PASS** manual smoke for follow/public-profile flows. M8 is the **polish and parity** milestone: finish deferred routing hygiene, ship **followers** list parity with **following**, lock a **collections** product decision (and only then consider schema work), and optionally improve **social count** presentation plus **share sheet / localization**.

This document is **plan and audit only** (no code changes in this step).

Sources reviewed: `docs/M7_SOCIAL_PROFILE_POLISH_CLOSEOUT_REPORT.md`, `docs/M7E3C_PUBLIC_PROFILE_FOLLOW_SMOKE_REPORT.md`, `docs/M7E3D_PUBLIC_PROFILE_FOLLOW_SMOKE_RESULT.md`, `lib/features/mono/**`, `lib/features/profile/**`, `nimon-backend/src/modules/users/**`, `nimon-backend/src/modules/user-follow/**`, `nimon-backend/prisma/schema.prisma`.

---

## 2. Current Deferred Scope From M7

From `docs/M7_SOCIAL_PROFILE_POLISH_CLOSEOUT_REPORT.md`:

| Area | Status / intent |
|------|------------------|
| **Legacy handle route cleanup** | `/profile/public?creator=<handle>` still accepted via `main.dart` query params; `PublicProfileScreen` still supports a **mock/local bundle** path when `creatorHandle` is set. Real Mono/notifications paths prefer `userId`; legacy remains for demos/mocks. |
| **Followers backend list + UI** | Backend exposes **`GET /v1/me/following`** (JWT) but **no** paginated “who follows user X” API. Flutter **`/profile/followers`** uses **static mock rows** (`kV1ProfileFollowers`) while **`/profile/following`** is API-backed (`profileFollowingPagerProvider` + `RemoteUserFollowRepository`). |
| **Collections decision** | Saved list is a **single** bookmark stream (`GET /v1/me/bookmarks`). Named folders/collections are **not** modeled in Prisma today. |
| **Social count UI polish** | Feed carries **`likesCount`** (`MonoFeedItem`, optimistic notifiers in `mono_screen.dart`); public profile shows **followers/following** counts from API. Placement/consistency across cards vs detail is still a **product/UI** exercise. |
| **Share sheet / localization** | Share is **clipboard-only** via `shareMonoLink` (`lib/features/mono/share_mono_link.dart`) with fixed English snackbars. No `share_plus`-style sheet and no centralized i18n for these strings yet. |

Smoke docs reinforce: **canonical route is** `/profile/public?userId=<uuid>`; legacy **`creator=`** is explicitly **deferred removal** until every backend surface supplies **`writerId`** (or an equivalent resolver exists).

---

## 3. UserId Canonical Routing Cleanup

### 3.1 Current behavior (audit)

- **`creatorProfileLocation`** (`lib/features/profile/creator_profile_location.dart`): prefers **`userId`** → `/profile/public?userId=…`; legacy **`?creator=`** only when **`allowLegacyHandle`** is true and handle non-empty.
- **Mono feed** (`mono_screen.dart`): passes **`allowLegacyHandle: false`** — real feed navigation will **not** fall back to handle.
- **Notifications** (`notifications_screen.dart`): passes **`allowLegacyHandle: true`** — mock actors can still resolve via handle (smoke report: demo surfaces).
- **Router** (`lib/main.dart`): `PublicProfileScreen` receives **`userId`** and **`creator`** query parameters from URI.
- **`PublicProfileScreen`**: branches between **remote `userId`** flow and **legacy/mock `creatorHandle`** bundle (`public_profile_screen.dart`).

### 3.2 Goal

- **Single mental model**: production navigation always targets **`userId`** when the backend exposes **`writerId`** on feed/detail DTOs (already true for mapped mono rows).
- **Reduce or isolate** the **`creator=`** path: either remove it after a **full entry-point audit**, or confine it to **debug/dev** builds only.

### 3.3 Work items (conceptual)

1. **Inventory** every `context.push` / `go` / deep link to `/profile/public` (grep + manual pass): Mono, profile, notifications, reader, share landing, tests.
2. **Replace** remaining mock-only flows that depend on handle with **`userId`** once those mocks carry stable IDs (or delete obsolete mocks).
3. **Optional backend helper** (product-dependent): e.g. **`GET /v1/users/by-handle/:handle/public-profile`** or resolve-on-feed — **only if** deep links must stay handle-based for marketing URLs; otherwise Flutter-only canonicalization may suffice.
4. **Router UX**: optional redirect from `?creator=` → `?userId=` after resolution (would require an API — see §9).

### 3.4 Tests already in place

- `test/features/profile/creator_profile_location_test.dart` encodes routing policy for `creatorProfileLocation`.

---

## 4. Followers List Backend + UI

### 4.1 Data model (no new migration for read path)

`UserFollow` in `prisma/schema.prisma` already indexes **`[followingId, createdAt]`**, which supports listing **followers of a given user** (edges where **`followingId = target`**). **`GET /v1/me/following`** lists rows where **`followerId = me`** — the symmetric query for followers uses the **`followingId`** side.

### 4.2 Backend gap

`UserFollowController` (`nimon-backend/src/modules/user-follow/user-follow.controller.ts`) currently exposes:

- `POST/DELETE /v1/users/:userId/follow`
- **`GET /v1/me/following`** (cursor pagination)

Missing for parity:

- **`GET /v1/users/:userId/followers`** (or **`GET /v1/me/followers`** for “my followers” only), with **cursor/limit** and response shape aligned with **`MeFollowingListItemDto`** (`user-follow.dto.ts`): profile fields + stable **`userId`** for navigation.

Design choices to lock before implementation:

- **Privacy**: public follower lists vs owner-only vs “followers hidden” (future setting).
- **Guest**: read-only public list vs auth-required (optional JWT pattern exists elsewhere via `OptionalJwtUserGuard`).

### 4.3 Flutter gap

`ProfileConnectionsScreen` (`profile_connections_screen.dart`):

- **`following`**: loads **`profileFollowingPagerProvider`** (remote).
- **`followers`**: still renders **`kV1ProfileFollowers`** mock list.

Parity work: **followers pager + repository method**, reuse row UI/tap navigation to **`/profile/public?userId=`** (already pattern in following list).

---

## 5. Collections Decision

### 5.1 Current behavior

- Bookmarks are **flat**: **`MonoBookmark`** ties **user + published mono**; **`GET /v1/me/bookmarks`** returns a single stream.

### 5.2 Product fork

| Option | Backend impact | Flutter impact |
|--------|----------------|------------------|
| **Saved-only (V1 freeze)** | None beyond current APIs | Profile Saved tab stays single list; marketing calls it “Saved” not “collections”. |
| **Collections v1.1 (folders)** | New Prisma models (e.g. collection + membership), migrations, CRUD + list APIs | Saved UI becomes folder picker + membership; larger UX scope. |

### 5.3 Recommendation for sequencing

- **Decide in M8** (spec + acceptance criteria only). **Defer implementation** until after **routing + followers** unless product prioritizes folders over parity.

---

## 6. Social Count UI Polish

### 6.1 Existing signals

- **Mono**: `likesCount` on **`MonoFeedItem`**, local optimistic updates in **`mono_screen.dart`**.
- **Public profile**: **`followersCount`**, **`followingCount`** from **`GET /v1/users/:userId/public-profile`** (`users.service.ts` aggregates via **`userFollow.count`**).

### 6.2 Polish themes (non-prescriptive)

- Consistent **typography / spacing** for counts on feed cards vs reader chrome vs profile header.
- Optional **abbreviation** (e.g. 1.2k) — purely presentation.
- Ensure **zero vs absent** semantics stay correct after optimistic follow/unfollow (already exercised in M7 smoke).

---

## 7. Share Sheet / Localization

### 7.1 Share

- Today: **`shareMonoLink`** copies **`shareUrl`** only; snackbars are hard-coded English strings.
- Optional upgrade: **`share_plus`** (or platform share) while **preserving** canonical URL as the shared payload; keep clipboard fallback where needed.

### 7.2 Localization

- Introduce **ARB / `intl`** (or project-standard l18n) for:
  - Share snackbars (“Link copied.” / “Share link is not available yet.”)
  - Social gates (“Sign in to …”) — scope carefully to avoid a giant sweep.

### 7.3 Dependency

Often scheduled **after** routing + followers unless release targets non-English locales immediately.

---

## 8. Recommended Implementation Split

| Slice | Scope | Primary surfaces |
|-------|--------|------------------|
| **M8a** | **UserId canonical routing cleanup**: audit, narrow/remove legacy `creator=` usage, align tests and demo mocks | `creator_profile_location.dart`, `main.dart`, `public_profile_screen.dart`, `notifications_screen.dart` |
| **M8b** | **Followers list**: NestJS paginated endpoint + Flutter pager + wire **`ProfileConnectionsScreen`(followers)** | `user-follow.*`, `profile_connections_screen.dart`, `remote_user_follow_repository.dart`, providers |
| **M8c** | **Collections**: written decision + optional spike PRD only; implement only if approved | docs + product; Prisma only if building folders |
| **M8d** | **Social count UI polish** | `mono_screen.dart`, profile/public widgets |
| **M8e** | **Share sheet + localization** | `share_mono_link.dart`, app l10n setup, optionally `pubspec` deps |

Order rationale: **routing hygiene** reduces duplicate code paths before adding **followers** UI that deep-links profiles; **collections** may require **migrations** so decision-first; **polish/i18n** are parallelizable once core parity is stable.

---

## 9. Risks / Scope Cuts

| Risk | Mitigation |
|------|------------|
| **Removing `creator=` breaks demos/notifications mocks** | Gate legacy route to **kDebugMode** or replace mock data with **`userId`** before removal. |
| **Followers privacy** | Specify policy up front; wrong default can leak social graph or frustrate creators. |
| **Following feed scalability** (M7 note) | Large follow graphs may need query tuning later — out of scope for M8 unless perf issues appear. |
| **Collections scope creep** | Treat folders as **M8c decision only** unless explicitly prioritized over followers. |
| **i18n sweep explosion** | Limit first pass to **share + auth gate strings** tied to social features. |

**Scope cuts** if schedule slips: defer **M8e** (share sheet/l10n); keep **M8a + M8b** as highest value for consistency and parity.

---

## 10. Exact Cursor Prompt For M8a

Use verbatim (adjust file paths if your branch differs):

```text
Implement M8a: UserId canonical public profile routing cleanup (Flutter-first; backend only if strictly required).

Context:
- M7 closed; canonical route is `/profile/public?userId=<uuid>`.
- `creatorProfileLocation` in lib/features/profile/creator_profile_location.dart prefers userId; legacy `?creator=` requires allowLegacyHandle.
- Mono uses allowLegacyHandle: false; notifications use allowLegacyHandle: true for mock actors.
- main.dart passes userId and creator query params into PublicProfileScreen; handle path can still show mock bundle.

Requirements:
1) Audit every navigation to `/profile/public` and document in a short bullet list (file + behavior): Mono, profile, notifications, tests, any deep links.
2) Eliminate production reliance on `?creator=` where a stable userId exists or can be added to mock data; keep legacy handle route only for isolated demo/debug surfaces if still needed.
3) Update PublicProfileScreen / router so the primary path is userId-backed; shrink or clearly fence mock-only code (kDebugMode or explicit demo flag if appropriate).
4) Update notifications entry points to pass userId when mock notifications include it; otherwise document why handle fallback remains.
5) Extend or adjust test/features/profile/creator_profile_location_test.dart for any new routing rules.
6) Run flutter analyze and flutter test on touched packages.
7) Write docs/M8A_USERID_ROUTING_CLEANUP_REPORT.md summarizing changes, remaining legacy surfaces, and manual smoke steps.

Do not run prisma migrations. Do not implement followers API or collections in this task.
```

---

### Output summary (plan-level)

| Question | Answer |
|----------|--------|
| **First M8 item to build** | **M8a — UserId canonical routing cleanup** (matches M7 closeout ordering: canonicalize on `userId`, retire redundant `creator=` usage where safe). |
| **Backend changes needed** | **M8a**: typically **none**; optional future endpoint only if product mandates handle-based deep links without client-side resolution. **M8b**: new **GET** list endpoint(s) for followers using existing **`user_follows`** — **no new tables**. |
| **Flutter screens likely to change** | **M8a**: `main.dart`, `public_profile_screen.dart`, `notifications_screen.dart`, possibly `profile_screen.dart` / tests. **M8b**: `profile_connections_screen.dart`, follow repositories/providers. **M8d/e**: `mono_screen.dart`, `share_mono_link.dart`, l10n bootstrap. |
| **Migration needed?** | **M8a/M8b**: **No** for followers listing (uses existing schema). **Collections folders**: **Yes, only if** product selects collections v1.1 with new tables. |
| **Biggest risk** | **Removing or narrowing the legacy handle route** before every entry point and demo carries **`userId`**, breaking notifications/demo flows or older bookmarks to profile. |
| **Recommended first implementation step** | **Inventory**: repo-wide search for `/profile/public`, `creator=`, `creatorHandle`, and `allowLegacyHandle`; produce a one-page **call-site matrix** (owner + requires userId?) before editing navigation. |
