# M22F-0 — Own Profile Language Flags and Collection Community Audit

**Phase:** Investigation only (no code, migrations, UI, or behavior changes).  
**Scope:** Own Profile owner surfaces, owner collection management, backend data/API parity for community flags and collection community rules.  
**Context:** M22D stamped `published_monos.contentLocale` / `learningLanguage`; M22E aligned public profile Collections with viewer language filtering (items only; owner APIs unchanged).

---

## A. Executive summary

1. **Own Profile** is implemented in `ProfileScreen` (`lib/features/profile/profile_screen.dart`) with three top tabs (`_ProfileIconTabs`): **Published**, **Workspace**, **Saved**, driven by a `TabController` + `PageView`.
2. **Published** uses `_FolderGroupList` with a segmented control (`_ProfileFolderFilter`): **Monos** | **Collections**.
3. **Published > Monos** loads via `profilePublishedMonoPagerProvider` → `GET /v1/published-monos` → `PublishedMonoListItemDto` → `_OneShortItem` → **`MonoStoryListRow`**. No community flag today.
4. **Published > Collections** loads via `myCreatorCollectionsNotifierProvider` → `GET /v1/me/creator-collections` → **`CollectionListRow`**. No community flag today.
5. **Workspace** loads via `profileWorkspaceDraftPagerProvider` → `GET /v1/story-drafts` (summary index) → **`_ProcessingDraftCard`**. Draft rows in DB have `contentLocale` / `learningLanguage` (M22D), but **list DTO omits them** — no flag today.
6. **Saved** loads via `profileSavedMonoPagerProvider` → `GET /v1/me/bookmarks` → `MonoFeedItem` → **`MonoStoryListRow`**. Bookmark list mapping does not include locale fields — no flag today.
7. **Owner collection detail** is `OwnerCreatorCollectionDetailScreen` → `GET /v1/me/creator-collections/:id/monos` (unfiltered, all catalog-visible items) → **`MonoStoryListRow`**. Same DTO gap as published list.
8. **Add-to-collection** (`showAddToCollectionSheet` / `POST .../items` / `.../bulk`) checks ownership and quotas only — **no `contentLocale` match**. An `en` mono can be added to a collection that only contains `my` monos today.
9. **Database:** `PublishedMono` and `StoryDraft` have nullable `contentLocale` / `learningLanguage`. **`CreatorMonoCollection` and `CreatorMonoCollectionItem` have no language columns.**
10. **Can flags show today without backend changes?** **No** for owner list surfaces. Locale exists in DB for published monos and full draft GET, but owner list/bookmark/collection-item APIs and Flutter DTOs do not expose it. UI has no `CommunityBadge` widget; only `content_community.dart` display helpers exist.

**Main gaps**

| Gap | Impact |
|-----|--------|
| `PublishedMonoListItemDto` lacks `contentLocale` / `learningLanguage` | Cannot badge Published monos, collection items, or infer collection community in UI |
| `DraftListSummaryResponseDto` lacks language fields | Cannot badge Workspace without N+1 full draft loads |
| Bookmark list DTO lacks language fields | Cannot badge Saved tab |
| No `CreatorMonoCollection.contentLocale` | Cannot badge collection cards or enforce same-community add |
| No add-to-collection locale validation (FE or BE) | Mixed-language collections allowed |
| Legacy `contentLocale = null` on old publishes | Flags need “legacy / unknown” treatment |

---

## B. Current UI map (from screenshots + code)

### Published > Monos

| Element | Source |
|---------|--------|
| Row widget | `MonoStoryListRow` |
| Thumb + JLPT | `PublicStoryThumb` (JLPT pill top-left on cover) |
| Title, description | Row text column |
| Publish kind | `publishBadgeText` → pill under title (`Read only` / `Full learn`) |
| Category / duration | Optional text under publish badge |
| Menu | `onMenuTap` → overflow |

**Visible badges today:** JLPT (on thumb), Read only / Full learn, category, duration.  
**Missing:** content community flag.

**Recommended placement:** Small community chip in the **chip row under the title** (same band as publish kind), **left of or on the same line as** the publish-kind pill — avoids competing with JLPT on the thumb. Alternative: second pill **bottom-left on thumb** (mirrors JLPT top-left) if chip row is crowded.

### Published > Collections

| Element | Source |
|---------|--------|
| Row widget | `CollectionListRow` (`public_profile_widgets.dart`) |
| Cover | `_StackedCollectionThumb` |
| Title, story count, optional description | Text column |
| Menu | Trailing overflow |

**Visible badges today:** None (title + “N stories” only).  
**Missing:** collection community flag.

**Recommended placement:** Compact badge on the **story count line** (e.g. `MY · 2 stories`) or **trailing corner of cover thumb** (consistent with mono thumb badges).

### Workspace (Draft / Editing)

| Element | Source |
|---------|--------|
| Row widget | `_ProcessingDraftCard` |
| Status | `Draft` or `Editing • Previously published` chip (red / blue) |
| Metadata chips | JLPT level, category, duration, sentence count, updated date |

**Visible badges today:** Draft/Editing status, JLPT, category, duration, sentences, updated.  
**Missing:** community flag.

**Recommended placement:** Add community chip in the **`Wrap` chip row** (line ~4885), **immediately after `statusChip`** and before level — keeps status + community readable at a glance.

### Saved

| Element | Source |
|---------|--------|
| Row widget | `MonoStoryListRow` (bookmark icon outside row, right) |
| Thumb + JLPT | Same as Published monos |

**Visible badges today:** JLPT, optional publish badge, description.  
**Missing:** community flag.

**Recommended placement:** Same as Published > Monos (chip under title or thumb corner). Saved rows omit category/duration often — community chip adds the most value there.

### Owner collection detail

Same **`MonoStoryListRow`** as Published monos list; no collection-level header badge in current UI (title from route args only).

---

## C. Current data model (Prisma)

### `PublishedMono` (`published_monos`)

| Column | Notes |
|--------|--------|
| `contentLocale` | `String?` — `en` \| `my` \| `ja`; null = legacy/untagged |
| `learningLanguage` | `String?` — V1 typically `ja`; null = legacy |
| Indexed | `@@index([contentLocale, learningLanguage, updatedAt])` |

Stamped at publish from draft → user prefs → fallback (M22D).

### `StoryDraft` (`story_drafts`)

| Column | Notes |
|--------|--------|
| `contentLocale` | `String?` — set on basics PATCH / import |
| `learningLanguage` | `String?` |

Full draft GET returns both in `StoryDraftBasicsDto`. **List summary query does not `select` these columns.**

### `CreatorMonoCollection` (`creator_mono_collections`)

| Column | Notes |
|--------|--------|
| Language | **None** |
| Fields | `title`, `description`, `coverImageUrl`, `visibility`, `sortOrder`, … |

### `CreatorMonoCollectionItem` (`creator_mono_collection_items`)

| Column | Notes |
|--------|--------|
| Language | **None** (community only via joined `PublishedMono`) |
| Rule | `@@unique([publishedMonoId])` — one collection per mono |

### Saved / bookmark (`mono_bookmarks`)

| Relation | Notes |
|----------|--------|
| `userId` + `publishedMonoId` | Points at `PublishedMono`; locale only on mono row |

**New columns if collection-level community (Option B/C):**

- `CreatorMonoCollection.contentLocale` (nullable for legacy — Option C)
- Optionally `CreatorMonoCollection.learningLanguage` if product wants collection-level learning target (usually redundant if V1 learning is always JA)

No change required on `CreatorMonoCollectionItem` if enforcement is “mono.contentLocale must match collection.contentLocale”.

---

## D. Current Flutter owner surfaces

### Widget / screen map

| Surface | Primary widget | File |
|---------|----------------|------|
| Profile shell | `ProfileScreen` | `profile_screen.dart` |
| Top tabs | `_ProfileIconTabs` | `profile_screen.dart` |
| Published sub-tabs | `_ProfileFolderFilter` inside `_FolderGroupList` | `profile_screen.dart` |
| Published > Monos | `_FolderGroupList` → `MonoStoryListRow` | `profile_screen.dart` |
| Published > Collections | `_FolderGroupList` → `CollectionListRow` | `profile_screen.dart` |
| Workspace | `_ProcessingDraftList` → `_ProcessingDraftCard` | `profile_screen.dart` |
| Saved | `ProfileSavedRemoteTab` | `profile_saved_remote_tab.dart` |
| Owner collection detail | `OwnerCreatorCollectionDetailScreen` | `owner_creator_collection_detail_screen.dart` |
| Add to collection | `showAddToCollectionSheet` | `add_to_collection_sheet.dart` |

### Shared row components

| Component | Used on |
|-----------|---------|
| `MonoStoryListRow` + `PublicStoryThumb` | Own Published Monos, Saved, owner/public collection mono lists, public profile monos |
| `CollectionListRow` | Own Published Collections, public profile collections |
| `_ProcessingDraftCard` | Workspace only |

**Reuse implication:** A single `CommunityBadge` (or thumb overlay helper) on `MonoStoryListRow` / `PublicStoryThumb` covers most mono surfaces; `CollectionListRow` needs a separate prop for collection-level badge.

### Providers / repositories / APIs

| Surface | Provider | Repository / API |
|---------|----------|------------------|
| Published Monos | `profilePublishedMonoPagerProvider` | `RemotePublishedMonoRepository` → `GET /v1/published-monos` |
| Collections list | `myCreatorCollectionsNotifierProvider` | `RemoteCreatorCollectionsRepository` → `GET /v1/me/creator-collections` |
| Workspace | `profileWorkspaceDraftPagerProvider` | Story draft repo → `GET /v1/story-drafts` |
| Saved | `profileSavedMonoPagerProvider` | `RemoteMonoSocialRepository.fetchBookmarkedPage` → `GET /v1/me/bookmarks` |
| Collection monos | Local state in detail screen | `fetchMyCollectionMonos` → `GET /v1/me/creator-collections/:id/monos` |
| Add to collection | `myCreatorCollectionsNotifierProvider` | `POST .../items/bulk`, create collection |

### Flag data availability (Flutter)

| Model | `contentLocale` | `learningLanguage` |
|-------|-----------------|---------------------|
| `PublishedMonoListItemDto` | **No** | **No** |
| `CreatorMonoCollection` | **No** | **No** |
| `DraftListSummaryDto` | **No** | **No** |
| `MonoFeedItem` (bookmarks) | **No** | **No** |
| Full `CreatorStoryV1` / draft GET | **Yes** (basics) | **Yes** |

Display helpers exist: `lib/core/settings/content_community.dart` (`ContentCommunityWire`, `contentCommunityDisplayLabel`, etc.). **No badge widget.**

---

## E. Current backend APIs / DTOs

| Endpoint | DTO | `contentLocale` | `learningLanguage` | Can show flag? | Filtered by viewer locale? |
|----------|-----|-----------------|---------------------|----------------|----------------------------|
| `GET /v1/published-monos` | `PublishedMonoListItemDto` | **No** (DB has; select omits) | **No** | **No** | **No** — all owner catalog-visible monos |
| `GET /v1/published-monos/:id` | `PublishedMonoDetailDto` | **No** in DTO | **No** | **No** | N/A (owner scope) |
| `GET /v1/story-drafts` | `DraftListSummaryResponseDto` | **No** | **No** | **No** | **No** — owner drafts |
| `GET /v1/story-drafts/:id` | `StoryDraftResponseDto.basics` | **Yes** | **Yes** | Yes (per-draft fetch) | N/A |
| `GET /v1/me/bookmarks` | Bookmark list items (inline shape) | **No** | **No** | **No** | **No** — all saved catalog-visible |
| `GET /v1/me/creator-collections` | `CreatorMonoCollectionDto` | **No** (no DB column) | **No** | **No** | **No** — all owner collections |
| `GET /v1/me/creator-collections/:id/monos` | `PublishedMonoListItemDto[]` | **No** | **No** | **No** | **No** — all items in collection |
| `GET /v1/users/:id/public/creator-collections` | `CreatorMonoCollectionDto` | **No** | **No** | **No** | **Yes** — hides empty-after-filter collections; filtered `itemCount` |
| `GET /v1/users/:id/public/creator-collections/:id/monos` | `PublishedMonoListItemDto[]` | **No** | **No** | **No** | **Yes** — viewer catalog locale |
| `GET /v1/mono/feed?writerId=` | Feed item shape | Varies by feed mapper | Varies | Public home — out of M22F scope | **Yes** (M22E feed policy) |
| `POST /v1/me/creator-collections/:id/items` | `{ created, itemId }` | N/A | N/A | N/A | No locale check |
| `POST /v1/me/creator-collections/:id/items/bulk` | counts only | N/A | N/A | N/A | No locale check |

**Backend changes needed for flags on owner lists:** Extend list `select` + DTO mapping for published mono and bookmark rows; extend `mapDraftListSummary` + `DraftListSummaryResponseDto`; optionally add collection-level fields on create/list.

---

## F. Current add-to-collection rule

### Where add/move happens

| Entry | Flow |
|-------|------|
| Published multiselect | `profile_screen.dart` → `showAddToCollectionSheet(publishedMonoIds: …)` |
| Collection sheet | Pick existing collection or create + `bulkAddItemsMine` |

### What the UI knows

| At picker time | Known? |
|----------------|--------|
| Mono `contentLocale` | **Not from list DTO** — only if separately loaded or inferred from selection context (not implemented) |
| Collection `contentLocale` | **No field** on `CreatorMonoCollection` |

### Enforcement today

| Layer | Same-community enforced? |
|-------|---------------------------|
| Flutter `add_to_collection_sheet.dart` | **No** |
| Backend `addItemMine` / `bulkAddItemsMine` | **No** — owner + quota + single-collection-per-mono only |

**Mismatch allowed?** **Yes** — e.g. `en` mono into a collection whose items are all `my`.

**Errors today on add failure:** `collection_not_found`, `not_owner_of_published_mono`, `QuotaExceededException` (collection item cap), duplicate idempotent success — **no `content_locale_mismatch`**.

### Recommended enforcement placement

| Layer | Role |
|-------|------|
| **Backend (required)** | Authoritative rule when `CreatorMonoCollection.contentLocale` is set; stable API contract |
| **Flutter (recommended)** | Picker filters collections / disables incompatible targets; better UX before round-trip |
| **Both** | Preferred for M22F implementation |

---

## G. Collection community design options

### Option A — No collection-level `contentLocale`; flags on items only

| | |
|--|--|
| **Pros** | No migration; mixed collections remain valid; smallest backend change (expose mono locale on list DTOs only) |
| **Cons** | Collection card cannot show one community without computing distinct locales client-side or extra API; add rule stays ambiguous |
| **Migration** | None for collections |
| **UI complexity** | Low for mono rows; medium if inferring “Mixed” on collection cards |
| **Backend complexity** | Low (DTO only) |

### Option B — `CreatorMonoCollection.contentLocale` required; strict add rule

| | |
|--|--|
| **Pros** | Clear creator mental model; simple collection badge; enforceable add API |
| **Cons** | Migration/backfill for existing rows; mixed legacy collections blocked or need one-time cleanup |
| **Migration** | **Yes** — backfill + NOT NULL or default |
| **UI complexity** | Medium — create/edit collection picker for community |
| **Backend complexity** | Medium — schema, create/update DTOs, add validation |

### Option C — Nullable `contentLocale`; null = legacy/mixed; new collections set locale

| | |
|--|--|
| **Pros** | Safest rollout; old mixed collections keep working; badge can show **Mixed** or **Unset**; new collections get strict adds |
| **Cons** | Two behaviors forever unless phased out; product must document null semantics |
| **Migration** | **Yes** — add nullable column; backfill where possible |
| **UI complexity** | Medium–high (warnings on mixed legacy) |
| **Backend complexity** | Medium — conditional validation (`if collection.contentLocale != null then match`) |

### Option D — Derive collection locale from first item

| | |
|--|--|
| **Pros** | No explicit column |
| **Cons** | Unstable on reorder/delete; empty collections undefined; misleading if items mixed |
| **Migration** | None |
| **UI complexity** | High edge cases |
| **Backend complexity** | Low column-wise, high behavioral ambiguity |

**Recommendation:** **Option C** for production safety (aligns with nullable legacy on `PublishedMono`), evolving toward **Option B** once mixed collections are cleaned up. **Option A** is acceptable as **phase 1** if collection badge/enforcement can wait. **Avoid Option D.**

---

## H. Migration / backfill options (analysis only — no DB execution)

Assume adding `CreatorMonoCollection.contentLocale` (nullable).

| Strategy | When to use | Empty collection | Mixed items (`my` + `en`) | Uniform items |
|----------|-------------|------------------|---------------------------|---------------|
| **First item** | Quick heuristic | Stay `null` until first add | Wrong if order changes | Works |
| **All items same** | Safest auto-backfill | `null` | `null` or special `mixed` sentinel* | Set to shared locale |
| **Null = legacy/mixed** | Option C | `null` | `null` + UI “Mixed” | Backfill to shared |
| **Manual choose** | Creator tools | Creator picks on edit | Creator resolves | Trivial |

\*Product may prefer explicit `mixed` label in UI without DB enum — derive at read time from distinct mono locales.

**Safest recommendation**

1. Add nullable `contentLocale` on collection.
2. Backfill: if all non-trashed items share one `PublishedMono.contentLocale`, set collection to that; else leave `null`.
3. UI: `null` → **Mixed / Legacy** badge on owner surfaces; warn on add when enforcing strict mode only for non-null collections.
4. New collections: require `contentLocale` at create (Flutter + API).
5. Do **not** auto-split mixed collections in M22F — optional later admin/creator tool.

**Old drafts `contentLocale = null`:** Show **neutral badge** (e.g. `—` or “Unset”) on Workspace; at publish, M22D resolver fills mono from prefs. Optional: prompt creator to set basics community before publish.

---

## I. UI badge recommendation (design only)

### Style

| Approach | Fit with current UI |
|----------|---------------------|
| **Short text `MY` / `EN` / `JA`** | **Best** — matches compact JLPT pill (10px, heavy weight on thumb) |
| Full label “Myanmar” | Too wide for list rows |
| Emoji flags | Inconsistent across platforms; accessibility concerns |
| `MY · JA` combined | Use only if product insists showing learning language; V1 learning is usually JA — **community-only badge is enough** for owner profile |

Use existing copy from `content_community.dart` for tooltips / accessibility labels; surface **wire code or 2-letter badge** on cards.

### Community vs community + learning

- **Owner profile:** **Community only** (`MY` / `EN` / `JA`) on cards; learning language is almost always JA in V1 and duplicates noise.
- **Settings / publish flows:** Continue to show both where users edit prefs.

### Owner vs public / home

- **Owner surfaces:** Stronger, always-visible chip (creator must distinguish catalogs).
- **Public / home:** Defer (per product brief); lighter or no badge until designed separately.

### Per-surface placement (summary)

| Surface | Placement |
|---------|-----------|
| Published Monos | Chip row under title, beside publish-kind pill |
| Saved | Same |
| Workspace | Chip `Wrap` after Draft/Editing status |
| Collection card | Story count line or thumb corner |
| Collection detail items | Same as mono row (per-item flags still useful if collection is Mixed) |

---

## J. Current behavior matrix

| Case | Scenario | Today | Flag possible today? |
|------|----------|-------|----------------------|
| **A** | Own Published > Monos, `contentLocale=my` | Listed in owner API (unfiltered) | **No** — DTO omits locale |
| **B** | Own Published > Monos, mixed `my` + `en` | All shown; creator cannot distinguish in UI | **No** |
| **C** | Workspace draft `contentLocale=my` | Stored in DB; list API omits | **No** (without per-row GET) |
| **D** | Saved `my` + `en` monos | All bookmarks shown (unfiltered) | **No** |
| **E** | Owner collection with `my` + `en` items | **Allowed** | **No** collection badge; per-item **No** |
| **F** | Add `en` mono to `my`-only collection | **Allowed** (FE + BE) | N/A |
| **G** | Public collection, viewer `my`+`ja`, mixed items | After M22E: viewer sees **only matching catalog-visible items**; collection hidden if filtered count 0 | Public list still **no locale on DTO**; filtering is server-side only |
| **H** | Collection with no `contentLocale` column | N/A — treat as legacy/mixed in future Option C | Badge would need derivation or “Mixed” |

---

## K. Recommended implementation phases (do not implement in M22F-0)

1. **Expose mono language metadata on owner/public list DTOs** — `PublishedMonoListItemDto`, bookmark items, `publishedMonoListItemFromRow` / catalog summary mapper; Flutter `PublishedMonoListItemDto` + `MonoFeedItem` mapper.
2. **Expose draft language on `GET /v1/story-drafts` summary** — select + `DraftListSummaryResponseDto` + `DraftListSummaryDto`.
3. **Add reusable `CommunityBadge` widget** — wire codes + null/legacy state; integrate into `MonoStoryListRow`, `PublicStoryThumb`, or chip row.
4. **Add `CreatorMonoCollection.contentLocale` (nullable)** — Prisma + migration + DTOs (Option C).
5. **Collection create/edit — community selection** — `CreateCreatorMonoCollectionDto`, Flutter create sheet.
6. **Enforce same `contentLocale` on add** — backend `addItemMine` / `bulkAddItemsMine` + Flutter picker filtering; new error e.g. `content_locale_mismatch`.
7. **Legacy / mixed handling** — UI copy, optional backfill job, tests.
8. **Tests** — backend spec for add rejection + list DTO fields; Flutter widget/mapper tests.

---

## L. Files likely to modify next

### Backend

- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/src/modules/published-monos/published-monos.dto.ts`
- `nimon-backend/src/modules/published-monos/published-mono-common.ts`
- `nimon-backend/src/modules/published-monos/published-monos.service.ts`
- `nimon-backend/src/modules/mono-social/mono-social.service.ts`
- `nimon-backend/src/modules/story-drafts/dto/story-draft.dto.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` (`mapDraftListSummary`, `findMany` select)
- `nimon-backend/src/modules/creator-collections/creator-collections.dto.ts`
- `nimon-backend/src/modules/creator-collections/creator-collections.service.ts` (`addItemMine`, `bulkAddItemsMine`, `create`, `listMine`)
- `nimon-backend/src/modules/creator-collections/creator-collections.service.spec.ts`
- `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.ts` (shared validation helpers if reused)

### Flutter

- `lib/features/profile/data/published_mono_dto.dart`
- `lib/features/profile/mono_story_list_row.dart`
- `lib/features/profile/public_profile_widgets.dart` (`CollectionListRow`, `PublicStoryThumb`)
- `lib/features/profile/profile_screen.dart` (`_mapPublishedDtosToLooseItems`, `_ProcessingDraftCard`)
- `lib/features/profile/presentation/profile_saved_remote_tab.dart`
- `lib/features/profile/data/creator_mono_collection.dart`
- `lib/features/profile/presentation/add_to_collection_sheet.dart`
- `lib/features/profile/owner_creator_collection_detail_screen.dart`
- `lib/features/create/data/dto/draft_list_summary_dto.dart`
- `lib/features/mono/data/remote_mono_social_repository.dart`
- `lib/features/mono/mono_feed_models.dart` (optional locale fields)
- `lib/core/settings/content_community.dart` (badge label helper)
- New: `lib/ui/widgets/community_badge.dart` (or similar)

### Tests

- `nimon-backend/src/modules/creator-collections/creator-collections.service.spec.ts`
- `nimon-backend/src/modules/published-monos/published-monos.service.spec.ts`
- `nimon-backend/src/modules/mono-social/mono-social.service.spec.ts`
- `test/features/profile/add_to_collection_sheet_test.dart`
- New/updated Flutter mapper and badge widget tests

---

## M. Open product questions

1. Should **collection community be required** for all new collections, or optional during transition?
2. Should **mixed-language collections** be allowed long term, or only as legacy?
3. Should old mixed collections display **“Mixed”** vs **“Unset”** vs hide badge?
4. Should **empty collections** force community selection at creation?
5. Should **Saved** tab show all bookmarks or filter by current app language settings?
6. Should badges show **community only** or **community + learning** (`MY · JA`)?
7. Badge copy: **`MY` / `EN`** vs full **Myanmar / English** labels?
8. Should **public profile / home** show badges in a later phase with lighter styling?
9. For **legacy `contentLocale = null` monos**, show as **international default**, **“Legacy”**, or hide until backfilled?
10. When enforcing collection locale, should **moving** a mono between collections re-validate locale on the target?

---

*Audit completed M22F-0 — investigation only; no repository behavior changed.*
