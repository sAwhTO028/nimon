# M17D — V1 free quota limits alignment audit

**Purpose:** Align **engineering reality** with **[M17D V1 product limits standard](./M17D_V1_PRODUCT_LIMITS_STANDARD.md)** — specifically **V1 free-tier ownership quotas**, not mono **content validation** (title/sentences/learn/media).

**M17D:** product / audit documentation. **M17E** shipped backend quota guards ([report](./M17E_BACKEND_FREE_QUOTA_GUARDS_REPORT.md)). **M17F** shipped Flutter quota UX ([report](./M17F_FLUTTER_FREE_QUOTA_ALERTS_REPORT.md)).

---

## 1. V1 free quota philosophy

Same as standard §1: **server-authoritative** quotas, **no silent failure**, **no auto-delete**, **pagination ≠ quota**, **premium messaging V2-only**.

**Audit lens:** backend quota **mutations** are implemented (**M17E**). Client UX + localization shipped in **M17F**.

---

## 2. Final V1 quota table (target vs current)

| Resource | V1 free max | Backend (post-M17E) | Flutter | Gap |
|----------|-------------|---------------------|---------|-----|
| Published monos | **30** | **Yes** — `publishReadOnly` + `restorePublishedMono` | **Yes** — M17F dialog | — |
| Saved monos | **50** | **Yes** — `MonoSocialService.bookmark` | **Yes** — M17F dialog | — |
| Collections | **10** | **Yes** — `CreatorCollectionsService.create` | **Yes** — M17F dialog | — |
| Collection items | **30** / collection | **Yes** — `addItemMine`, `bulkAddItemsMine` | **Yes** — M17F dialog | — |
| Draft stories | **50** | **Yes** — `StoryDraftsService.createDraft` | **Yes** — M17F dialog | — |

---

## 3. What is not capped in V1

| Area | Confirmed intent | Notes for audit |
|------|------------------|-----------------|
| Followers / following | **No cap** | No change required for quota work. |
| Public / home feed reading | **No ownership quota** | `mono-feed` etc. remain pagination-only; **do not** conflate **`limit`** query param with user-owned row caps. |
| Mono content validation | **Separate track** | Title, description, `STORY_SENTENCE_LIMITS`, learn modules, media — see **§10 Appendix**. |

---

## 4. Backend enforcement points (implemented in M17E)

See **[M17E_BACKEND_FREE_QUOTA_GUARDS_REPORT.md](./M17E_BACKEND_FREE_QUOTA_GUARDS_REPORT.md)** for exact files and counting rules. Summary:

| Quota `key` | Hook |
|-------------|------|
| `published_mono_limit_reached` | `StoryDraftsService.publishReadOnly` (first `publishedMono.create`); `PublishedMonosService.restorePublishedMono` |
| `saved_mono_limit_reached` | `MonoSocialService.bookmark` |
| `collection_limit_reached` | `CreatorCollectionsService.create` |
| `collection_item_limit_reached` | `CreatorCollectionsService.addItemMine`, `bulkAddItemsMine` |
| `draft_story_limit_reached` | `StoryDraftsService.createDraft` |

---

## 5. Flutter UX / alert requirements (audit checklist)

| # | Requirement | Current (typical) | Gap |
|---|-------------|-------------------|-----|
| F1 | Parse **`code === "quota_exceeded"`** + **`key`**, **`limit`**, **`current`** | `tryParseQuotaExceededFromHttpBody` + repositories | — |
| F2 | Show **dialog** (and snack where legacy) per screen | Dialog via `showQuotaExceededDialog` | — |
| F3 | **Localized** strings via ARB quota keys | `app_en` / `app_ja` / `app_my` | — |
| F4 | **No silent failure** — user sees why save/publish failed | Typed exception + UI | — |
| F5 | Optional **“Premium coming later”** secondary | `quotaPremiumComingLaterCta` where copy mentions Premium / V2 | — |

---

## 6. Error contract (audit)

**Normative JSON** (must match standard §6 after M17E):

```json
{
  "code": "quota_exceeded",
  "key": "<specific_limit_key>",
  "limit": 30,
  "current": 30
}
```

**Audit:** **M17E** returns this shape with **HTTP 403** for quota blocks. **M17F** must parse and localize.

---

## 7. Localization keys (audit)

| API `key` | ARB key (actual) | Status |
|-----------|-------------------|--------|
| `published_mono_limit_reached` | `publishedMonoLimitReachedTitle` / `publishedMonoLimitReachedMessage` | Added (M17F) |
| `saved_mono_limit_reached` | `savedMonoLimitReachedTitle` / `savedMonoLimitReachedMessage` | Added (M17F) |
| `collection_limit_reached` | `collectionLimitReachedTitle` / `collectionLimitReachedMessage` | Added (M17F) |
| `collection_item_limit_reached` | `collectionItemLimitReachedTitle` / `collectionItemLimitReachedMessage` | Added (M17F) |
| `draft_story_limit_reached` | `draftStoryLimitReachedTitle` / `draftStoryLimitReachedMessage` | Added (M17F) |

All templates should interpolate **`limit`** and **`current`** for clarity.

---

## 8. Premium V2 notes

- V1 UI must **not** imply paid unlock is available — only **“Premium coming later”** where product approves.
- V2 may extend JSON (e.g. `upgrade: "premium"`) — **not** part of M17D contract.

---

## 9. P0 / P1 / P2 implementation plan

### P0 (release blockers for “free quotas shipped”)

1. **M17E:** ~~Implement all **five** backend guards + **`quota_exceeded`** body (§6) on block.~~ **Done.**
2. **M17F:** ~~Flutter **alert + l10n** for every **`key`** (§7); no silent failures.~~ **Done** ([report](./M17F_FLUTTER_FREE_QUOTA_ALERTS_REPORT.md)).

### P1 (should fix before V1 quota GA)

- Integration tests: boundary **`limit-1`** ok, **`limit`** blocked with correct **`key`**.
- Optional **preflight** endpoint or piggyback counts on existing list DTOs to drive proactive UI.

### P2 (post-V1)

- Analytics, admin overrides, abuse detection, premium SKUs.

### Milestone mapping (revised)

| Milestone | Deliverable |
|-----------|-------------|
| **M17E** | Backend **quota guards** + standardized **`quota_exceeded`** responses (§6); Jest for each mutation. |
| **M17F** | Flutter **quota alert handling** + **localization** (§5–§7); wire create/save/publish/collection flows. |
| **M17G** | **Phone smoke** + release verification: each quota hit path, regression on M17C published list, saved list, drafts, collections. |

---

## 10. Appendix — Content validation (explicitly out of M17D quota scope)

The **previous M17D draft** mixed **pagination defaults**, **story title/description**, **`STORY_SENTENCE_LIMITS`**, learn tables, **media bytes/MIME**, and **profile DTO max lengths**. Those are **content and payload validation limits**, not **free-tier ownership quotas**.

| Topic | Canonical location (do not duplicate full audit here) |
|-------|---------------------------------------------------------|
| Story title / description / sentences | `nimon-backend/src/common/validation/story-validation.ts`, `publish-validation.ts`; Flutter `lib/core/validation/story_validators.dart` |
| Learn vocab / grammar / quiz | `learn-validation.ts`; `learn_validators.dart` |
| Collection **name** text (not item count quota) | `collection-validation.ts`; `collection_validators.dart` |
| Profile PATCH field lengths | `me-profile.dto.ts`; `profile_validators.dart` |
| Media type/size | `media.validation.ts`, `media-file-limits.ts`, multer; Flutter upload mappers |

**Future work:** if product wants **strict parity** between content validators and UI `maxLength`, track as a **separate** milestone from **M17E/M17F/M17G quota** work (optional small tickets), not as part of M17D.

---

## Commands (when M17E / M17F land)

```text
dart format <touched.dart>
flutter analyze <touched paths>
flutter test test/features/create
flutter test test/features/profile
cd nimon-backend
node node_modules/jest/bin/jest.js --runInBand
node node_modules/@nestjs/cli/bin/nest.js build
```

**M17G:** manual device matrix + checklist in release doc.
