# M22F-1 — Owner Surface Mono Community Flags

**Phase:** Implementation complete.  
**Audit reference:** [M22F0_LANGUAGE_FLAGS_AND_COLLECTION_COMMUNITY_AUDIT.md](./M22F0_LANGUAGE_FLAGS_AND_COLLECTION_COMMUNITY_AUDIT.md)

---

## A. What was implemented

- Owner/private mono and draft list APIs now expose `contentLocale` and `learningLanguage` on list DTOs (no filtering changes).
- Flutter parses locale fields on published mono, draft summary, and bookmark rows.
- Reusable **`CommunityBadge`** widget shows compact **`MY` / `EN` / `JA`** or **`—`** for legacy/null `contentLocale` (community only; no learning language in badge).
- Badges wired on:
  - Own Profile → Published → Monos
  - Own Profile → Workspace (Draft / Editing)
  - Own Profile → Saved
  - Owner collection detail item rows
- **Not in scope (unchanged):** collection-level `contentLocale`, add-to-collection enforcement, collection card badges, public/home UI, feed filtering.

---

## B. Backend DTO/API changes

| Endpoint | Change |
|----------|--------|
| `GET /v1/published-monos` | `select` adds `contentLocale`, `learningLanguage`; `PublishedMonoListItemDto` includes both |
| `GET /v1/published-monos/:id` | Same columns on detail select (extends list DTO) |
| `GET /v1/me/creator-collections/:id/monos` | Locale via `publishedMonoListItemFromRow` (full mono row) |
| `GET /v1/users/.../public/.../monos` | Locale via `publishedMonoListItemFromCatalogSummaryRow` + `PUBLIC_COLLECTION_MONO_SELECT` (data only; no new public UI) |
| `GET /v1/me/bookmarks` | `MonoBookmarksListItemDto` adds `contentLocale`, `learningLanguage` |
| `GET /v1/story-drafts` | `DraftListSummaryResponseDto` adds `contentLocale`, `learningLanguage` |

**Shared mapping:** `publishedMonoLocaleFields()` in `published-mono-common.ts`.

**Filtering:** Unchanged on all owner endpoints (still all catalog-visible owner rows).

---

## C. Flutter model changes

| Model | Fields added |
|-------|----------------|
| `PublishedMonoListItemDto` | `contentLocale?`, `learningLanguage?` |
| `DraftListSummaryDto` | `contentLocale?`, `learningLanguage?` |
| `MonoFeedItem` | `contentLocale?` (for Saved + collection detail via mapper) |

**Parsers:** `publishedMonoListItemDtoFromBackendJson`, `DraftListSummaryDto.fromJson`, `RemoteMonoSocialRepository` bookmarks, `RemotePublishedMonoRepository` now delegates list parsing to shared JSON helper.

---

## D. CommunityBadge design

- **File:** `lib/ui/widgets/community_badge.dart`
- **Labels:** `contentCommunityBadgeShortLabel()` in `content_community.dart`
- **Style:** Small chip (~10px bold), `primaryContainer` tint for known locales, muted surface for legacy `—`
- **Semantics:** Tooltip-style label via `contentCommunityBadgeSemanticsLabel` (full community name / “Community unset”)
- **MonoStoryListRow:** `showCommunityBadge` (default `false`) + `contentLocale`; badge in chip row beside publish-kind pill
- **Workspace:** `CommunityBadge` in `_ProcessingDraftCard` chip `Wrap` after Draft/Editing status chip

---

## E. Surfaces updated

| Surface | Widget | `showCommunityBadge` |
|---------|--------|----------------------|
| Published > Monos | `MonoStoryListRow` | `true` when `isBackendPublished` |
| Workspace | `CommunityBadge` in `_ProcessingDraftCard` | always (owner remote drafts) |
| Saved | `MonoStoryListRow` | `true` |
| Owner collection detail | `MonoStoryListRow` | `true` |
| Public profile / Home | — | **not enabled** (default false) |
| Collection cards | — | **not added** |

---

## F. Tests run

### Backend (Jest)

```text
--testNamePattern="M22F-1|contentLocale and learningLanguage"
Test Suites: 4 passed
Tests:       7 passed
```

Includes:

- `published-mono-locale-fields.spec.ts`
- `story-drafts.service.spec.ts` (list summary locales)
- `mono-social.service.spec.ts` (bookmarks)
- `creator-collections.service.spec.ts` (owner collection monos)

### Flutter

```text
flutter test \
  test/core/settings/content_community_badge_test.dart \
  test/ui/widgets/community_badge_test.dart \
  test/features/profile/published_mono_locale_dto_test.dart \
  test/features/create/draft_list_summary_locale_dto_test.dart
All tests passed.
```

---

## G. What was intentionally not implemented

- `CreatorMonoCollection.contentLocale` column or migration
- Same-community add-to-collection validation (Flutter or backend)
- Collection card / picker community badges
- `learningLanguage` in list badges (stored in API for future use only)
- Public profile / Home Mono badge UI
- `commonLanguage` / `sourceLanguage`
- Any change to feed or saved/published **filtering**

---

## H. Manual verification

1. **Published > Monos:** Publish or view monos with `contentLocale` `my` and `en`; confirm **MY** / **EN** chips next to Read only / Full learn.
2. **Workspace:** Open drafts with basics community set; confirm badge after Draft/Editing chip. Old drafts with null locale show **—**.
3. **Saved:** Bookmark monos from different communities; Saved tab shows per-row **MY** / **EN** / **—** (all bookmarks still listed).
4. **Owner collection detail:** Open a collection; each mono row shows community badge.
5. **Legacy null:** Rows with `contentLocale: null` show **—** without crash.
6. **Collection cards:** No community badge on collection list rows.
7. **Add to collection:** Can still add mixed-community monos (unchanged).

---

## Key files touched

**Backend:** `published-monos.dto.ts`, `published-mono-common.ts`, `published-monos.service.ts`, `mono-social.dto.ts`, `mono-social.service.ts`, `story-draft.dto.ts`, `story-drafts.service.ts`, `creator-collections.service.ts` (`PUBLIC_COLLECTION_MONO_SELECT`), `search.service.ts`, specs listed above.

**Flutter:** `published_mono_dto.dart`, `remote_published_mono_repository.dart`, `draft_list_summary_dto.dart`, `mono_feed_models.dart`, `mono_feed_item_mapper.dart`, `remote_mono_social_repository.dart`, `mono_story_list_row.dart`, `profile_screen.dart`, `profile_saved_remote_tab.dart`, `owner_creator_collection_detail_screen.dart`, `content_community.dart`, `community_badge.dart`, new tests.
