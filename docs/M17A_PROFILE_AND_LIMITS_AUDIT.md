# M17A Profile and Limits Audit

## Scope

Read-only audit (no code, backend, Flutter, or test changes). Covers:

1. **Issue 1** — Public profile “identity regression” (missing display name / handle on phone; bio visible).
2. **Issue 2** — Own Profile **Published > Monos** shows 20 while public shows 21.
3. **Issue 3** — Inventory of **V1 limits** and a **product-first** policy proposal (not implemented).

References: `public_profile_screen.dart`, `public_profile_remote_nested_scroll.dart`, `profile_published_mono_pager.dart`, `remote_published_mono_repository.dart`, `pagination_defaults.dart`, `published-monos.service.ts` (backend), validation modules under `nimon-backend/src/common/validation/`, `docs/M14J_A10_PUBLIC_PROFILE_HERO_VISIBILITY_HOTFIX_REPORT.md`, `docs/M13_NIMON_VALIDATION_AND_LIMITATION_STANDARD.md`, `docs/P0_PROFILE_PAGER_PUBLISH_VISIBILITY_FIX_REPORT.md`.

---

## Issue 1 Public Profile Identity Regression

### 1–2. Are display name / handle widgets still rendered?

**Yes.** In `lib/features/profile/public_profile_screen.dart`, when `_remoteProfile != null`, the `profileInfoPanel` builds:

- `Text(displayName, …)` with `ValueKey('publicProfileDisplayName')` inside `ValueKey('publicProfileIdentityBlock')`.
- If `handle.isNotEmpty`, a second `Text(handle, …)` with `ValueKey('publicProfileHandle')`.
- If `bio.isNotEmpty`, bio `Text` with `ValueKey('publicProfileBio')`.

`displayName` is `rp.effectiveDisplayName` (never null/empty as a **string**: falls back to trimmed handle, then `'Creator'`). So the display-name `Text` is **always** present in the tree when the remote profile loaded.

### 3. Keys

| Key | Present |
|-----|--------|
| `publicProfileIdentityBlock` | Yes |
| `publicProfileDisplayName` | Yes (spec asked for name/handle/bio; display name uses this key) |
| `publicProfileHandle` | Yes, conditional on non-empty handle |
| `publicProfileBio` | Yes, conditional on non-empty bio |

### 4. Could name/handle be “hidden” by …?

| Mechanism | Assessment |
|-----------|------------|
| Conditional null/empty | Handle row omitted only if `handle.isEmpty`. Display name line is **not** conditional on non-empty (always `Text(displayName)`). |
| Same color as background | Display `Text` uses `theme.textTheme.headlineSmall` **without explicit `color`**. Handle/bio use `onSurfaceVariant`. If `headlineSmall` resolved poorly on a specific theme/device, contrast could fail (hypothesis). |
| Clipping | Hero `Stack` uses `clipBehavior: Clip.hardEdge` on **cover only**; identity lives in a **separate** `SliverToBoxAdapter` below `SliverAppBar` (`PublicProfileRemoteNestedScroll`). No obvious clip on the identity column from that Stack alone. |
| Stack / Positioned overlap | Identity is not inside the cover `Stack`; overlap with hero overlay is unlikely unless `NestedScrollView` / `FlexibleSpaceBar` paint order or **parallax** causes visual overlap on specific devices (needs device repro). |
| `kPublicProfileIdentityBelowHero` too small | M14J-A10 reduced spacer **104 → 52** (`docs/M14J_A10_PUBLIC_PROFILE_HERO_VISIBILITY_HOTFIX_REPORT.md`). Risk: headline sits **too high** relative to collapsing header / overlap perception; bio starts after name+optional handle+spacing, so bio can look “directly under hero” if name/handle are **invisible** rather than missing from tree. |
| Cover overlay | Overlay row is **inside** cover `Stack` at `bottom: 12`; identity is below flexible space. |
| `SliverAppBar` / `FlexibleSpaceBar` | Title in app bar uses `AnimatedOpacity(opacity: innerBoxIsScrolled ? 1 : 0)` — only affects **toolbar** title, not the main identity block. |

### 5. What changed in M14J-A10 that could hide name/handle?

- Shorter cover band (`kRemotePublicCoverImageHeight` 168 → 146).
- **`kPublicProfileIdentityBelowHero` 104 → 52** — less vertical offset between cover bottom and identity block; could contribute to **visual crowding** or overlap **on some viewports** if combined with font metrics / text scale.
- `Stack` `Clip.hardEdge` on cover — should not clip the following sliver.

### 6. Why could bio show while name/handle “do not”?

- **Bio** is in a separate conditional (`if (bio.isNotEmpty)`). If API returns **bio** but **empty/null displayName and handle** in JSON: `effectiveDisplayName` becomes **`'Creator'`**; handle line is **skipped**. User might perceive “no real name/handle” while bio is populated — **data shape**, not missing widgets.
- If **contrast** fails for `headlineSmall` / `titleSmall` but `bodyMedium` (bio) still reads, bio could appear “alone” under the hero.

### 7. Widget tests vs phone

Repo tests (`public_profile_header_hero_composition_test.dart`, `public_profile_hero_overlay_tuning_test.dart`, etc.) **find** `publicProfileDisplayName` / `publicProfileHandle` with **mock** `PublicCreatorProfile` data. That proves layout **can** show name/handle under test conditions; it does **not** prove the same API payload + theme + device combination as the phone screenshot.

### 8. Likely follow-up change locations (for M17B — not done here)

- `lib/features/profile/public_profile_screen.dart` — `profileInfoPanel` `Text` styles for display name and handle: add **explicit** `color: scheme.onSurface` / `scheme.onSurfaceVariant` (and re-check spacing `kPublicProfileIdentityBelowHero`).
- If API fields are wrong: `PublicCreatorProfile.fromJson` / backend public-profile payload (out of M17B Flutter-only scope if server fix).

**Recommendation (Issue 1):** Treat as **M17B** hotfix: restore guaranteed visible **display name + handle** in `profileInfoPanel` (explicit colors + confirm spacer vs M14J-A10), keep hero/cover/avatar/stats architecture, keep action row → TabBar and TabBar → first mono spacing goals (≤40px targets per prior specs), **do not** change public pagination/collections in the same pass.

---

## Issue 2 Own Profile Published Monos 20 Cap

### 1–2. Provider / endpoint

| Surface | Component | Endpoint |
|---------|-----------|----------|
| Own Profile Published > Monos (remote) | `profilePublishedMonoPagerProvider` → `ProfilePublishedMonoPager` → `RemotePublishedMonoRepository.fetchPage` | `GET /v1/published-monos` with query from `PageRequest.toQueryParameters()` (`limit`, `sort`, optional `cursor`) |

### 3. Hardcoded limit 20?

**Yes (Flutter).** `PaginationDefaults.profilePageLimit = 20` in `lib/core/pagination/pagination_defaults.dart`. `ProfilePublishedMonoPager` uses `PageRequest(limit: PaginationDefaults.profilePageLimit)` for first page, refresh, and loadMore.

### 4–5. Cursor pagination / loadMore wired?

- **Flutter:** `loadMore()` exists and appends; `profile_screen.dart` wires `onLooseListNearEnd` to `loadMore()` when `RemoteBackendConfig.useRemoteDrafts` is true. Near-end uses `ScrollUpdateNotification` and `pixels >= maxScrollExtent - 220`.
- **Backend:** `PublishedMonosService.listPublishedMonos` returns `{ items, nextCursor: null }` **always**. DTO type `PublishedMonoListResponseDto` declares `nextCursor: null` (literal). **No cursor**, **no `hasMore` field** in response.

### 6. Shared constant with public profile?

**No.** Public creator monos use `PublicProfileMonosNotifier.pageLimit = 10` and `GET /v1/mono/feed?writerId=…` with real cursor/`hasMore` from feed. Own published uses **`/v1/published-monos`** + **`profilePageLimit` 20**.

### 7. Why public 21 vs own 20?

| Path | Behavior |
|------|----------|
| **Public** | Mono feed service supports **cursor + hasMore**; notifier can load more pages → can reach 21 items. |
| **Own** | First request asks for **20** rows. Backend `findMany` `take = limit` (clamped 1..100). Response **always** `nextCursor: null`. Flutter parses missing `hasMore` as **false** (`_hasMoreFromJson`). So **`canLoadMore` is false** — **second page never requested** even if UI scroll triggers `loadMore`. Maximum visible without API change is **one page = 20** for default limit. |

### 8. Backend vs Flutter “cap”

- **Flutter:** chooses **page size 20** and implements pager UX.
- **Backend:** returns **at most `limit` items** per call and **does not expose pagination** for this list today (`nextCursor` always null). So the **21st mono cannot be fetched** through the current contract without either raising `limit` (e.g. to 50) or adding **real cursor pagination** on `/v1/published-monos`.

### 9–10. Options & least risky V1 fix

| Option | Description | Risk |
|--------|-------------|------|
| **A** | Owner published monos **pagination** end-to-end: backend cursor + `hasMore`, Flutter already has pager shape | **Correct** long-term; **requires backend** + contract update (user asked not to change backend in this audit; future milestone). |
| **B** | Temporarily **raise** Flutter `limit` (e.g. 50) to pick up 21 without backend cursor | Quick; still capped at backend max 100; **not** scalable for power users. |
| **C** | Reuse **public** mono feed for own profile tab | Couples owner UI to catalog feed semantics / filters; **risky** for parity and auth. |
| **D** | Backend “return all for V1” | Large payloads; **not** ideal vs pagination. |

**Recommendation (Issue 2):** **M17C** — Implement **proper cursor pagination** on `GET /v1/published-monos` (backend) + align Flutter `PageResult` with `nextCursor`/`hasMore`; keep **public profile** on existing feed path. Until then, a **documented temporary** raise of first-page `limit` (≤ backend max) is possible but should be labeled **technical debt**.

**Secondary check:** `profile_screen.dart` filters loose published rows with `_hidePublishedItemForWorkspaceEditing`. If exactly **one** mono is hidden while “editing”, UI could show **20 of 21** even before pagination — worth confirming on repro account.

---

## Issue 3 V1 Limits Policy

### Product principles (proposal only)

1. **Published monos:** No arbitrary low cap for V1 creators; **paginate everywhere** (owner list, public catalog, bookmarks). Page sizes **defaults** (e.g. 15–20) with **max** (e.g. 50) enforced server-side.
2. **Drafts:** **Paginate** (already cursor-based on backend); avoid implying “full list” in one shot. Optional high **soft** cap later for abuse.
3. **Saved / bookmarks:** High practical cap with **pagination** (mono social APIs already take `limit`).
4. **Collections:** Keep **title length** and item rules; cap **collection count** / **items per collection** only if product requires anti-abuse (define numbers explicitly).
5. **Story sentences / learn modules:** Keep **JLPT × duration band** table as canonical (`STORY_SENTENCE_LIMITS`); tune only with product + performance review.
6. **Media:** Strict **byte** limits (env-tunable defaults: cover **10MB**, audio **50MB** in `media-file-limits.ts`).
7. **Profile fields:** Keep backend validation bands (display name, handle, bio, lines).
8. **API page sizes:** Single doc: default **20**, max **50** (align `PaginationDefaults` with backend clamps per resource).

---

## Current Limits Inventory

Abbreviations: **BE** = backend authoritative, **FL** = Flutter client constant / request.

| Area | Current limit | Where enforced | Backend? | Flutter? | User-facing message? | Recommendation |
|------|----------------|----------------|----------|----------|----------------------|----------------|
| Owner published monos page | **20** / request | `PaginationDefaults.profilePageLimit`; `ProfilePublishedMonoPager` | BE `take = min(max(limit,1),100)`; **no cursor** | FL chooses 20 | Indirect (missing items) | Add BE cursor + `hasMore`; align FL |
| Published monos BE max per request | **100** | `published-monos.service.ts` | Yes | Request clamp via `PageRequest` max 50 in FL | — | Document BE max vs FL max |
| Public creator monos page | **10** | `PublicProfileMonosNotifier.pageLimit` | Feed service | FL | — | Keep; document |
| Mono feed catalog limit | default parse in service | `MonoFeedController` + `MonoFeedService` | Yes | `monoFeedPageLimit` 15 FL | — | Align doc defaults |
| Story drafts list | default **50**, max **50** | `LIST_DEFAULT_LIMIT` / `LIST_MAX_LIMIT` | Yes | `workspacePageLimit` 20 FL pager | — | Product: “workspace page 20, BE supports 50” |
| Followers/following pages | **20** | `PaginationDefaults.defaultPageLimit` | BE follow services clamp **1–30** | FL 20 | — | Align FL with BE max 30 or document |
| Saved/bookmarks page | **20** | `profile_saved_mono_pager` pattern | `mono-social` default limit **15** in controller | FL 20 | — | Verify BE accepts 20; document |
| Trashed published page | **20** | `profile_trashed_published_mono_pager` | Same published list | FL | — | Same as owner published |
| Collection title length | **1–40** chars | `collection-validation.ts` | Yes | Mirror in UX if needed | `messageKey` | Keep |
| Profile display name | **1–30** chars | `profile-validation.ts` | Yes | Edit profile | l10n keys | Keep |
| Profile handle | **3–24** (normalized) | `profile-validation.ts` | Yes | Edit profile | l10n keys | Keep |
| Profile bio | **≤150** chars, **≤3** lines | `profile-validation.ts` | Yes | Edit profile | l10n keys | Keep |
| Story title (publish-like) | **5–80** chars, emoji rules | `story-validation.ts` | Yes | Flutter publish path | M13 | Keep |
| Story description (publish) | **≤280** chars (see file for line rules) | `story-validation.ts` | Yes | — | M13 | Keep |
| Sentence / char bands | JLPT × `3_5` / `5_7` / `7_9` table | `STORY_SENTENCE_LIMITS` | Yes | Flutter should mirror for UX | M13 | Single product table |
| Tags / hashtags / URLs (story) | various max (e.g. 4 tags, 2 emojis) | `story-validation.ts` | Yes | — | M13 | Keep |
| Media cover upload | **10MB** default | `readCoverMaxBytesFromEnv` | Yes (Multer) | Client before upload | Media messages | Env for ops |
| Media audio upload | **50MB** default | `readAudioMaxBytesFromEnv` | Yes | Client | Media messages | Env for ops |
| Creator collection monos page | default **20**, max **50** | `creator-collections.service.ts` `DEFAULT_MONO_PAGE` / `MAX_MONO_PAGE` | Yes | FL public collection may pass limit | — | Document |
| Max published monos per user | **None found** in audit sample | — | — | — | — | V1: none; paginate lists |
| Max drafts per user | **None found** | — | — | — | — | V1: rely on pagination + cost |

*Note: Flutter-side duplicate validators may exist for UX; authoritative limits are backend modules above.*

---

## Root Causes

| Issue | Root cause (audit conclusion) |
|-------|--------------------------------|
| **1** Identity | Widgets exist; likely **styling/contrast** (`headlineSmall` without explicit color), **API empty handle/displayName** (user sees only bio + fallback “Creator”), and/or **M14J-A10 reduced spacer** causing crowded layout on phone. Needs **device + network payload** confirmation. |
| **2** 20 vs 21 | **Primary:** Backend `/v1/published-monos` **does not implement cursor pagination** (`nextCursor` always null); Flutter uses **limit=20** and **`hasMore` false** → **no second page**. **Secondary:** possible **one row hidden** by workspace editing filter. Public profile uses **different endpoint** with real paging. |

---

## Recommended Implementation Split

| Milestone | Scope |
|-----------|--------|
| **M17B** | Public profile identity hotfix: explicit colors / spacing; verify API fields; widget/golden tests; **no** hero architecture tear-down; **no** pagination/collection behavior change. |
| **M17C** | Own profile published monos: **backend cursor + `hasMore`** for `/v1/published-monos`, Flutter pager wired to real `nextCursor`; optional scroll-threshold tuning; tests; **do not** change public profile list path. |
| **M17D** | V1 product limits standard doc + align BE/FL validation messages and constants (`PaginationDefaults` vs BE clamps); tests per M13 patterns. |

---

## Risks

- **Issue 1:** Fixing colors without checking **payload** may miss empty handle/displayName from API.
- **Issue 2:** Raising limit only (Option B) **masks** the bug for small counts but fails at 101+ monos.
- **Limits policy:** Divergence between FL `PaginationDefaults.maxPageLimit` (50) and BE follow clamp (30) can confuse QA.

---

## Next Steps

1. Capture **network JSON** for `/v1/users/:id/public-profile` on repro phone (displayName, handle, bio).
2. Re-run **widget tests** on CI; optional **golden** test for identity block on dense DPI.
3. Product decision on **M17C** backend priority for published-monos cursor.
4. Schedule **M17D** doc + constant alignment after M17B/C land.

---

## Part F — Output Summary

| Question | Answer |
|----------|--------|
| Public profile name/handle widgets still exist? | **Yes** — `Text(displayName)` + conditional handle `Text`; keys `publicProfileDisplayName`, `publicProfileHandle`, `publicProfileIdentityBlock`. |
| Why name/handle not visible? | **Most likely:** empty API handle + fallback display string perceived as “missing”; and/or **missing explicit text colors** on headline; and/or **M14J-A10 spacer 52** crowding. **Needs device + payload confirmation.** |
| Exact fix recommended? | **M17B:** explicit `ColorScheme` colors on identity texts; verify `PublicCreatorProfile` JSON; tune `kPublicProfileIdentityBelowHero` only if repro shows overlap. |
| Own profile 20 cap root cause? | **Backend** list returns **only one page** with **`nextCursor: null` always**; **Flutter** requests **limit=20** → **20 items max**; **`hasMore` false** → **`loadMore` ineffective.** Optional **second** cause: one row hidden by editing filter. |
| Backend or Flutter cap? | **Both:** Flutter chooses 20; backend **does not paginate** this list. |
| Recommended own profile fix? | **M17C:** add **cursor + hasMore** to `/v1/published-monos` and wire existing pager (least risky long-term). Short-term: raise limit only with explicit debt label. |
| Current limits inventory completed? | **Yes** for sampled surfaces (profile pagination defaults, published monos BE, drafts list, story/profile/collection/media validation). Further grep may find edge constants. |
| V1 limits policy recommended? | **Yes** — see **Issue 3** principles + table **Recommendation** column. |
| Split into M17B / M17C / M17D? | **Yes** — see **Recommended Implementation Split**. |
