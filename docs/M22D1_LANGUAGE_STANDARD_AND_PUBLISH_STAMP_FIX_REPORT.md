# M22D-1 — Language Standard and Publish Stamp Fix

Date: 2026-06-03  
Source audit: `docs/M22D0_CURRENT_LANGUAGE_FEED_PUBLISH_FLOW_AUDIT.md`  
Phase: Lock V1 language standard; fix `published_monos` language stamping.

---

## A. Standard locked (V1)

| Concept | Wire / DB field | Meaning in V1 |
|---------|-----------------|---------------|
| Learning target | `learningLanguage` | Language being learned (V1: `ja` only in UI/API) |
| Community / audience | `contentLocale` | Explanation community (Settings label: **Content community**). Documented alias: **communityLanguage** — not a separate column |
| Not in V1 | `commonLanguage` | Not implemented; must not affect feed |
| Not in V1 | `sourceLanguage` | Not implemented |

**Allowed V1 pairs**

- `learningLanguage=ja`, `contentLocale=en`
- `learningLanguage=ja`, `contentLocale=my`
- Future: `learningLanguage=en`, `contentLocale=my` (learning `en` not enabled in UI yet)

**Rejected**

- `ja` + `ja`, `en` + `en` (same code for both axes)

**Feed (unchanged)**

- Filters only `contentLocale` + `learningLanguage` with legacy `OR null` inclusion
- Guest defaults: `en` + `ja`
- Authenticated: saved `UserPreference` (no `commonLanguage`, no `en` fallback for `my` in this phase)

---

## B. Files modified

### Backend (`nimon-backend`)

| Area | Files |
|------|--------|
| Validation | `src/common/validation/language-pair-validation.ts`, `.spec.ts` |
| Schema / migration | `prisma/schema.prisma`, `prisma/migrations/20260603140000_m22d1_draft_language_metadata/migration.sql` |
| Drafts / publish | `src/modules/story-drafts/story-drafts.service.ts`, `story-drafts.service.spec.ts` |
| DTOs | `src/modules/story-drafts/dto/story-draft.dto.ts`, `story-draft.requests.ts` |
| Preferences | `src/modules/auth/auth.service.ts`, `me.profile.controller.spec.ts` |
| Feed tests only | `src/modules/mono-feed/mono-feed.service.spec.ts` |

### Flutter (`lib/`, `test/`)

| Area | Files |
|------|--------|
| Language pair helper | `lib/core/settings/language_pair.dart`, `test/core/settings/language_pair_test.dart` |
| Draft model / wire | `lib/features/create/story_v1_model.dart`, `data/dto/story_draft_dto.dart`, `data/story_draft_mapper.dart` |
| Import | `import/nimon_import_mapper.dart`, `import/nimon_import_validator.dart` |
| Creator session | `story_creator_provider.dart` |
| Settings UI | `lib/features/settings/settings_screen.dart` |
| Feed debug | `lib/features/mono/data/remote_mono_feed_repository.dart` (optional debug logs; no token) |
| Tests | `nimon_import_*_test.dart`, `story_draft_language_defaults_test.dart` |

### Docs

- `docs/M22D1_LANGUAGE_STANDARD_AND_PUBLISH_STAMP_FIX_REPORT.md` (this file)

**Explicitly not changed:** feed pagination, M22B feed summary `select` shape, publish HTML/numeric validation, HTML generator tools, `commonLanguage` / `sourceLanguage`, DB rename of `contentLocale`.

---

## C. DB migration

Migration: `20260603140000_m22d1_draft_language_metadata`

```sql
ALTER TABLE "story_drafts" ADD COLUMN "contentLocale" TEXT;
ALTER TABLE "story_drafts" ADD COLUMN "learningLanguage" TEXT;
UPDATE "story_drafts" SET "learningLanguage" = 'ja' WHERE "learningLanguage" IS NULL;
```

**Backfill decision**

- `learningLanguage`: set to `'ja'` for all existing rows (matches prior de-facto publish target and only V1 learning code).
- `contentLocale`: left **NULL** on existing rows so publish can still resolve from current `user_preferences.contentLocale` rather than guessing `en` for Myanmar users who already had drafts.

---

## D. Draft metadata changes

- `story_drafts.contentLocale` and `story_drafts.learningLanguage` (nullable) on Prisma `StoryDraft`.
- Create/update draft APIs accept optional basics fields; service resolves write tags via draft body → user preference → `en`/`ja` defaults.
- Flutter `StoryBasics` / `StoryDraftBasicsDto` / mapper carry the same optional fields.
- Manual creator: new/reset local drafts default `contentLocale` / `learningLanguage` from `UserPreferences` (provider-injected defaults).
- Remote `createDraft` on backend also resolves from request body → prefs when columns absent.

---

## E. Import mapping changes

- `nimonImportMeta.contentCommunity` → `draft.basics.contentLocale` (wire code: `my` | `en` | `ja`).
- `nimonImportMeta.learningLanguage` → `draft.basics.learningLanguage` (`ja` wire).
- `promptSourceNote` unchanged for prompt mode text; language no longer relies on note alone.
- Import validator rejects resolved same pair (`ja`+`ja`) with `import.languagePairSameNotAllowed` before account-mismatch checks where applicable.

---

## F. Publish stamping changes

**Before:** `publishReadOnly` / `publishFullLearn` always wrote `contentLocale='en'`, `learningLanguage='ja'`.

**After:** `resolvePublishLanguageTags()`:

1. Draft `contentLocale` / `learningLanguage` when set and valid
2. Else `user_preferences` for owner
3. Else `en` / `ja`
4. `assertDistinctLanguagePair` — publish fails with `language_pair_same_not_allowed` for `ja+ja`

Stamped onto `published_monos` on create/update during publish.

---

## G. Same-language validation

| Surface | Behavior |
|---------|----------|
| A. `PATCH /v1/me/preferences` | Rejects patch that would set `contentLocale === learningLanguage` |
| B. Flutter Settings | Blocks picking community equal to learning; hides Japanese community when learning is Japanese |
| C. Import | Rejects import when meta resolves to same pair |
| D. Publish | Rejects publish when resolved pair is same |

---

## H. Feed behavior unchanged

- `mono-feed.service.ts` filter logic unchanged: `(contentLocale = effective OR null) AND (learningLanguage = effective OR null)`.
- No `commonLanguage` column or filter.
- No relaxed filter and no `en` fallback when user preference is `my`.
- M22B: `listFeed` `findMany` still does **not** select `content` JSONB (regression test retained).

---

## I. Tests run

### Backend (Jest)

```text
language-pair-validation.spec.ts — pass
story-drafts.service.spec.ts — pass (incl. publishReadOnly stamps my+ja, ja+ja publish reject, updateDraft mocks)
mono-feed.service.spec.ts — pass (incl. M22B no content select, my+ja filter, strict not en+ja for my user)
me.profile.controller.spec.ts — targeted: PATCH ja+ja reject, PATCH my+ja pass
```

### Flutter

```text
test/core/settings/language_pair_test.dart
test/features/create/nimon_import_validator_test.dart
test/features/create/nimon_import_mapper_test.dart
test/features/create/story_draft_language_defaults_test.dart
```

---

## J. Manual verification

1. Settings → **Content community** = Myanmar (`my`), **Learning language** = Japanese (`ja`).
2. Import or create a Japanese mono; confirm draft basics show `contentLocale=my`, `learningLanguage=ja` (or publish falls back to prefs if draft columns null).
3. Publish (read-only or full learn).
4. DB: `published_monos.contentLocale = 'my'`, `learningLanguage = 'ja'`.
5. Same account **For You** shows the mono (was empty before M22D-1 when rows were stamped `en`).
6. Set Content community = International / English (`en`); confirm feed shows `en`+`ja` catalog rows.
7. Attempt Japanese community + Japanese learning in Settings or import (`ja`+`ja`) — blocked in UI and API.

---

## Root cause fixed (M22C class)

Myanmar (`contentLocale=my`) users saw an empty authenticated feed because every publish stamped `en`, while the feed strictly matched account `my`+`ja`. Publish now stamps draft/import/preference-resolved tags so catalog rows align with feed filters.
