# M22D-0 — Current Language / Feed / Publish Flow Audit

Date: 2026-06-03  
Scope: **Investigation only** — no code, migrations, or behavior changes.

This audit maps **today’s** implementation against the **proposed** language standard discussed for M22D (terminology below for comparison only).

---

## A. Executive summary

1. **Two feed/publish language columns exist end-to-end:** `contentLocale` (community / audience) and `learningLanguage` (target language learned). There is **no** `communityLanguage`, `commonLanguage`, or `sourceLanguage` field in Prisma, Flutter models, or feed APIs.
2. **Flutter Settings** exposes **Content community** (`contentLocale`: `my` | `en` | `ja`) and **Learning language** (`learningLanguage`: **`ja` only** in UI; backend PATCH allows only `ja`).
3. **Import JSON** uses human labels in `nimonImportMeta`: `learningLanguage`, `contentCommunity` (not `contentLocale`). Import validates both against **account preferences**, then stores metadata only inside **`StoryBasics.promptSourceNote`** (text), not as draft columns.
4. **`StoryDraft` / `CreatorStoryV1` have no language columns.** Language is not part of the draft contract on wire or in `story_drafts` table.
5. **Publish always stamps** `published_monos.contentLocale = 'en'` and `learningLanguage = 'ja'` (hardcoded in `story-drafts.service.ts`). It does **not** read user preferences or import meta at publish time.
6. **Feed filters** on `contentLocale` + `learningLanguage` with **OR null** legacy inclusion. Guest defaults: `en` + `ja`. Authenticated: `UserPreference` row (no query override from Flutter).
7. **`commonLanguage` is not used anywhere** in the repo (no matches). It does **not** affect feed filtering.
8. **No validation** prevents `learningLanguage` and `contentLocale` from being the same code (e.g. **`ja` + `ja`** is selectable in Settings today).
9. **Documented bug class (M22C):** Myanmar account (`contentLocale=my`) + catalog rows stamped `en` at publish → **empty For You** while guest (`en` default) sees stories.
10. **Per-mono language metadata (proposed)** is **not implemented**; only account-level preferences + publish-time hardcoded mono columns.

### Main mismatches with proposed standard

| Proposed | Current |
|----------|---------|
| Each Mono carries its own language metadata | Only `published_monos` columns; always `en`/`ja` at publish; draft has none |
| Feed uses learning + community only; not `commonLanguage` | Already true (`commonLanguage` absent) |
| `learningLanguage` ≠ `communityLanguage` | **Not enforced**; `ja`+`ja` allowed in Settings |
| Publish stamps from draft/settings/import | **Hardcoded `en`/`ja`** |
| Account prefs = defaults only | Prefs **directly drive feed SQL** for authenticated users |
| `commonLanguage` / `sourceLanguage` helpers | **Do not exist** in codebase |

---

## B. Current terminology map

| UI name (Flutter l10n) | Flutter field | Backend / API field | DB column | Meaning today | Allowed values today |
|------------------------|---------------|---------------------|-----------|---------------|-------------------|
| App language | `UserPreferences.appLocale` | `appLocale` | `user_preferences.appLocale` | Device UI locale | `system`, `en`, `ja`, `my` |
| Content community | `UserPreferences.contentLocale` | `contentLocale` | `user_preferences.contentLocale` | Audience / explanation community for feed defaults | `my`, `en`, `ja` |
| Learning language | `UserPreferences.learningLanguage` | `learningLanguage` | `user_preferences.learningLanguage` | Target language being learned | **`ja` only** (UI + backend PATCH) |
| *(none)* | — | — | — | Proposed `communityLanguage` | **Alias of `contentLocale` in practice** |
| *(none)* | — | — | — | Proposed `commonLanguage` | **Not implemented** |
| *(none)* | — | — | — | Proposed `sourceLanguage` | **Not implemented** |
| Import: Content community | `NimonImportMeta.contentCommunity` | — | — | JSON human label → maps to `contentLocale` wire | Myanmar/Burmese→`my`, International/English→`en`, Japanese→`ja` |
| Import: Learning language | `NimonImportMeta.learningLanguage` | — | — | JSON label → maps to prefs wire `ja` | Japanese; English rejected at import |
| Published mono tags | — | `contentLocale`, `learningLanguage` | `published_monos.*` | Catalog feed filters | `en`/`my`/`ja` + `ja`; publish writes **`en`/`ja`** |
| Creator prompt note | `StoryBasics.promptSourceNote` | `promptSourceNote` | `story_drafts.promptSourceNote` | Free text; import embeds meta lines | No structured language fields |

**Naming note:** Settings label **“Content community”** maps 1:1 to DB **`contentLocale`**, not a separate `contentCommunity` column. Import JSON uses **`contentCommunity`** as the metadata field name.

---

## C. User preferences — current behavior

### Flutter

| Item | Detail |
|------|--------|
| Model | `lib/features/settings/data/user_preferences_repository.dart` → `UserPreferences` |
| Fields | `appLocale`, `contentLocale`, `learningLanguage`, `themeMode`, `readingTextSize`, `showExplanations` |
| Defaults | `contentLocale: 'en'`, `learningLanguage: 'ja'` |
| UI | `lib/features/settings/settings_screen.dart` |
| Content community picker | **Myanmar** (`my`), **International / English** (`en`), **Japanese** (`ja`) |
| Learning language picker | **Japanese** (`ja`) only; “More languages” disabled |
| Normalization | `lib/core/settings/content_community.dart` — Myanmar/Burmese/`my` → `my`; International/English → `en`; Japanese → `ja` |
| Feed refresh | `user_preferences_notifier.dart` — changing `contentLocale` or `learningLanguage` calls `monoFeedPagerProvider.refresh()` and `followingMonoFeedPagerProvider.refresh()` |
| Same-language check | **None** |

### Backend

| Item | Detail |
|------|--------|
| Model | `prisma/schema.prisma` → `UserPreference` |
| API | `GET/PATCH /v1/me/preferences` (`me.controller.ts`, `auth.service.ts`) |
| DTO | `me-preferences.dto.ts` — `CONTENT_LOCALES = ['my','en','ja']`, `LEARNING_LANGUAGES = ['ja']` |
| Defaults | `DEFAULT_ME_PREFERENCES`: `contentLocale: 'en'`, `learningLanguage: 'ja'` |
| Normalization | `mono-feed.service.ts` — `safeStoredContentLocale` / `safeStoredLearningLanguage` (invalid stored → fall back to `en`/`ja`) |
| `contentLocale` meaning | Comment: “Community / content region”; equivalent to proposed **communityLanguage** |
| `commonLanguage` in DB | **No** |

### Does Flutter allow `learningLanguage == contentLocale`?

**Yes, in UI:** user can set Content community **Japanese** (`ja`) and Learning language **Japanese** (`ja`). Backend PATCH accepts `contentLocale: 'ja'` and `learningLanguage: 'ja'`. **No guard** in Flutter or backend preferences.

---

## D. Import / draft — current behavior

### JSON metadata (`nimonImportMeta`)

| Field in import JSON | Parsed? | Stored on draft? | Validated against settings? |
|----------------------|---------|------------------|------------------------------|
| `learningLanguage` | Yes → `NimonLearningLanguage` | Only in `promptSourceNote` text | Yes — must match `UserPreferences.learningLanguage` (`ja`); **English import blocked** |
| `contentCommunity` | Yes → `NimonContentCommunity` | Only in `promptSourceNote` text | Yes — must match `UserPreferences.contentLocale` (via `contentCommunityMatchesPreference`) |
| `promptDataTab` | Yes | In `promptSourceNote` | Meta required (Manual/AI mode) |
| `publishKind`, `createdForEmail`, etc. | Yes | In `promptSourceNote` | Email + meta rules |
| `contentLocale` | **Not a JSON field** | — | Uses `contentCommunity` label instead |
| `commonLanguage` | **Absent** | — | — |
| `sourceLanguage` | **Absent** | — | — |

**Files:** `nimon_import_meta.dart`, `nimon_import_enums.dart`, `nimon_import_validator.dart`, `nimon_import_mapper.dart`, `nimon_hidden_json_import_flow.dart`.

**Normalization:** Myanmar / Burmese / `my` → `my`; International / English aliases → `en`; Japanese → `ja` (`content_community.dart`, `nimon_import_enums.dart`).

**Persistence:** `mapNimonImportPayloadToCreatorStoryV1` builds `StoryBasics` **without** language columns; `_buildImportPromptSourceNote` appends lines like `learningLanguage=…`, `contentCommunity=…`.

### Draft model

| Layer | `learningLanguage` | `contentLocale` / community | `commonLanguage` | `sourceLanguage` |
|-------|-------------------|----------------------------|------------------|------------------|
| Prisma `StoryDraft` | **No column** | **No column** | **No** | **No** |
| `CreatorStoryV1` / `StoryBasics` | **No field** | **No field** | **No** | **No** |
| `StoryDraftDto` (wire) | **No** | **No** | **No** | **No** |

### Manual vs imported creation

| Path | Language source used |
|------|----------------------|
| Manual creator | Account prefs only indirectly (HTML/publish validation uses level/band/`promptSourceNote`; **not** stored on draft) |
| AI JSON import | Import meta validated vs **current account** `learningLanguage` + `contentLocale`; then meta copied into **`promptSourceNote` only** |
| Publish | **Ignores** draft note and prefs → **`en`/`ja`** on `published_monos` |

---

## E. Publish — current behavior

**File:** `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`

| Action | `contentLocale` | `learningLanguage` | Uses user prefs? | Uses import/draft meta? |
|--------|-----------------|-------------------|------------------|-------------------------|
| `publishReadOnly` create/update | **`'en'`** hardcoded | **`'ja'`** hardcoded | **No** | **No** (only `promptSourceNote` on draft for HTML rules) |
| `publishFullLearn` update | **`'en'`** hardcoded | **`'ja'`** hardcoded | **No** | **No** |

**`buildPublishedMonoContentAndSummary`:** sets `content` JSON (`core`, optional `learn`, `publishKind`, `sourceDraftId`, timestamps). **No language keys** inside `content` blob.

**M22B denormalized fields** (`coverImageUrl`, `publishKind`, `hasAudio`, counts): **no language fields** — correct, no impact on locale filtering.

**Migrations:**

- `20260508210000_m11e_published_mono_locales` — added `contentLocale`, `learningLanguage` (+ index)
- `20260509120000_m11i_reading_prefs_feed_compat` — nullable columns; backfill NULL → `en`/`ja`
- `20260603120000_m22b_published_mono_feed_summary` — **does not touch** locale columns

---

## F. Feed — current behavior

### Backend (`GET /v1/mono/feed`)

| Item | Behavior |
|------|----------|
| Query params | `limit`, `cursor`, `sort`, `level`, `category`, `writerId`, **`contentLocale`**, **`learningLanguage`**, **`following`** |
| Guest (`userId` null) | Effective: **`en`** + **`ja`** |
| Authenticated, no query | Loads `user_preferences`; applies stored codes (invalid → `en`/`ja`) |
| Query override | `contentLocale` / `learningLanguage` query wins over prefs |
| Filter | `(contentLocale = effective OR contentLocale IS NULL) AND (learningLanguage = effective OR learningLanguage IS NULL)` + catalog visibility |
| `commonLanguage` | **Not referenced** |
| `en` fallback for `my` | **No** — strict match on effective community code (+ null) |
| `following=true` | Same locale filter **plus** `ownerId IN (followed)`; empty follows → `[]`; **401** if no auth |
| Response DTO | Summary only — **no** `contentLocale` / `learningLanguage` on wire (`mono-feed.dto.ts`) |

### Flutter feed request

| Item | Behavior |
|------|----------|
| For You | `RemoteMonoFeedRepository.fetchFeedPage` — **no** `contentLocale` / `learningLanguage` query params |
| Auth | Optional `Authorization` → backend sets `userId` → prefs apply |
| Guest | No auth header → guest defaults `en`/`ja` |
| Account Myanmar | Prefs `my`/`ja` → server filters `my` — **empty** if catalog is all `en` (M22C) |
| Following | Separate repo; `following=true`; auth required |

---

## G. Current behavior matrix

Feed rule: row visible iff catalog-visible AND `(row.contentLocale == effectiveCommunity OR row.contentLocale IS NULL)` AND `(row.learningLanguage == effectiveLearning OR row.learningLanguage IS NULL)`.

**Today’s publish stamp:** almost all rows **`contentLocale=en`**, **`learningLanguage=ja`**.

| Case | User / guest effective filter | Published mono tags | Show in For You? |
|------|------------------------------|---------------------|------------------|
| **A** | `ja` + `my` | `ja` + `my` | **Show** (if such rows exist; publish does not create them today) |
| **B** | `ja` + `my` | `ja` + `en` | **Hide** (`en` ≠ `my`; null does not include explicit `en`) |
| **C** | Guest → `en` + `ja` | `ja` + `en` | **Show** |
| **D** | `ja` + `en` | `ja` + `en` | **Show** |
| **E** | `en` + `my` | `en` + `my` | **N/A for learning `en`** — backend cannot save `learningLanguage=en` (PATCH rejects). If imagined: **Show** when both match |
| **F** | `en` + `en` | — | **Not allowed:** `learningLanguage=en` not in `LEARNING_LANGUAGES`. Closest today: **`ja`+`ja`** (Settings allows) vs mono `ja`+`en` → **Hide** (community mismatch) |

**Case F (rephrased for today’s codes):** Settings **`contentLocale=ja`** + **`learningLanguage=ja`** — **allowed**, no validation. Published mono **`en`/`ja`** → **Hide** for that user (community `ja` vs row `en`).

---

## H. `commonLanguage` / `sourceLanguage` — current status

| Concept | Exists in code? | Stored? | Used in feed? | Used in publish? |
|---------|-----------------|---------|---------------|------------------|
| `commonLanguage` | **No** (repo-wide grep: zero) | **No** | **No** | **No** |
| `sourceLanguage` | **No** | **No** | **No** | **No** |

Sentence glosses / explanations in content JSON may use `en` / `my` keys per line — that is **content shape**, not catalog metadata or feed filtering.

---

## I. Same-language pair validation

| Check | Current status |
|-------|----------------|
| Prevent `en` + `en` (learning + community) | **Partially N/A** — learning cannot be `en` in backend prefs |
| Prevent `ja` + `ja` | **Not prevented** — Settings offers both Japanese community and Japanese learning |
| Import validator | Checks import meta **matches account** prefs; does **not** check prefs internal consistency |
| Publish validation | HTML/readiness rules only; **no** language-pair rule |
| Backend `PATCH /v1/me/preferences` | **No** pair validation |
| Feed | No pair rule; only applies separate filters |

**Where validation likely belongs (recommendation only):**

1. **Settings / PATCH preferences** — reject invalid pairs at change time  
2. **Import context** — optional secondary check after prefs are valid  
3. **Publish** — stamp from draft metadata; reject publish if pair invalid  
4. **Feed** — should not fix bad pairs; only filter on stored mono tags  

---

## J. Risks / bugs found

| ID | Severity | Issue |
|----|----------|-------|
| R1 | **BLOCKER** | Publish hardcodes `contentLocale=en` while users/readers filter by `UserPreference.contentLocale` → Myanmar (`my`) accounts see **empty feed** (M22C, verified on global-test API) |
| R2 | **HIGH** | No per-mono language metadata; account prefs act as **permanent feed identity** contrary to product direction |
| R3 | **HIGH** | Draft/import language context **lost at publish** (only `promptSourceNote` text; not read for stamping) |
| R4 | **HIGH** | `ja`+`ja` community/learning pair **allowed**; conflicts with proposed invariant |
| R5 | **MEDIUM** | Terminology drift: `contentCommunity` (import) vs `contentLocale` (DB/API) vs UI “Content community” |
| R6 | **MEDIUM** | Flutter does not pass feed query params; debugging/locale override requires backend prefs change |
| R7 | **MEDIUM** | `contentLocale=ja` in Settings means “Japanese community,” easy to confuse with learning Japanese |
| R8 | **LOW** | M11e doc says filter `contentLocale == effective` only; **code includes `OR null`** (doc drift) |
| R9 | **LOW** | Feed response omits mono locale tags — client cannot explain empty feed |

---

## K. Recommended implementation phases (no implementation)

1. **Lock terminology** — `contentLocale` = communityLanguage; document `learningLanguage`; defer `commonLanguage` / `sourceLanguage` until product defines storage.
2. **Add draft + publish metadata** — structured fields on draft (or `content` meta block) + stamp `published_monos` from draft/import, not hardcoded `en`/`ja`.
3. **Publish stamp rules** — map `contentCommunity` → `contentLocale`; copy `learningLanguage`; optional future `sourceLanguage` inside `content` only.
4. **Feed filter** — keep **only** `learningLanguage` + `contentLocale` (community); explicitly exclude any future `commonLanguage` from `listFeed`.
5. **Same-language pair validation** — Settings PATCH + import + publish gate (`ja`+`ja`, `en`+`en` when `en` learning exists).
6. **Account prefs semantics** — prefs as **default for new drafts** and **default feed lens**, overridable per mono; document fallback policy (e.g. show `null`-tagged legacy rows).
7. **V1 fallback policy (product)** — decide whether `my` readers see `en`-tagged catalog until `my`-stamped content exists (M22C workaround vs data fix).

---

## L. Files likely to modify in next phase

### Flutter

- `lib/features/settings/data/user_preferences_repository.dart`
- `lib/features/settings/presentation/providers/user_preferences_notifier.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/core/settings/content_community.dart`
- `lib/features/create/story_v1_model.dart` (or `StoryBasics`)
- `lib/features/create/data/story_draft_mapper.dart`
- `lib/features/create/data/dto/story_draft_dto.dart`
- `lib/features/create/import/nimon_import_meta.dart`
- `lib/features/create/import/nimon_import_mapper.dart`
- `lib/features/create/import/nimon_import_validator.dart`
- `lib/features/create/import/nimon_hidden_json_import_flow.dart`
- `lib/features/mono/data/remote_mono_feed_repository.dart`
- `lib/features/mono/data/mono_feed_providers.dart`
- `test/features/settings/user_preferences_notifier_feed_refresh_test.dart`
- `test/features/create/nimon_import_validator_test.dart`
- `test/features/create/content_community_normalization_test.dart`

### Backend

- `nimon-backend/prisma/schema.prisma`
- `nimon-backend/src/modules/auth/dto/me-preferences.dto.ts`
- `nimon-backend/src/modules/auth/auth.service.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.controller.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.dto.ts` (optional: expose locale on summary)
- `nimon-backend/src/modules/mono-feed/mono-feed.service.spec.ts`
- New migration (when approved) for draft language columns if added

### Docs / tools

- `docs/M11E_CONTENT_LOCALE_FEED_INTEGRATION_REPORT.md` (align with null OR + per-mono plan)
- `tool/html_generator/*.html` (if generator should emit `commonLanguage` / `sourceLanguage` later)

---

## M. Unresolved product questions

1. Should **`contentLocale` column be renamed** to `communityLanguage` in API/DB, or keep `contentLocale` as wire name?
2. When should **`commonLanguage`** be persisted (draft only, publish JSON, or nowhere in V1)?
3. Is **`sourceLanguage`** the story body language (e.g. Japanese prose for JA-learners) and is it feed-relevant?
4. For **legacy `null` tags**, do they mean “visible to all communities” or “inherit publisher default”?
5. **Fallback policy:** should `my` users see `en`-stamped monos until creators publish `my`-tagged content?
6. Will **learning `en`** launch soon (import already has `english` enum stub)? How does that interact with **community `en`** ban?
7. Should **feed** use account prefs when authenticated, or only per-mono tags (prefs become default for *new* filter, not SQL filter)?
8. Should **Settings `contentLocale=ja`** remain (Japanese *community*) while learning is Japanese — or is that pair always invalid?
9. Should **import** continue to require meta match to **account** prefs, or to **draft** language fields once added?
10. **Following feed:** same community/learning filter as For You — confirm intended when follows publish cross-community content.

---

## Appendix — doc vs code conflicts

| Doc | Code reality |
|-----|----------------|
| M11E: filter `contentLocale == effective` (no mention of null) | Code: **`OR contentLocale IS NULL`** (and same for `learningLanguage`) |
| M21H: “No feed filtering changes in this phase” | M11e already shipped feed filtering by `contentLocale` / `learningLanguage` |
| M11 spec: `contentLocale=my` means JA-learning for Myanmar audience | Aligns with usage; publish still stamps **`en`** |

---

## Appendix — prior reports (cross-reference)

| Report | Relevant finding |
|--------|------------------|
| `M11E_CONTENT_LOCALE_FEED_INTEGRATION_REPORT.md` | Feed prefs + query params; Flutter refresh; publish stamp `en`/`ja` |
| `M22A_HOME_MONO_FOR_YOU_LOADING_AUDIT.md` | Remote feed; Flutter does not send locale query params |
| `M22B_PUBLISHED_MONO_FEED_SUMMARY_BACKEND_REPORT.md` | Denormalized summary; no locale columns |
| `M22C_MONO_FEED_ACCOUNT_EMPTY_INVESTIGATION.md` | `my` account + `en` publishes → empty feed |

---

**No code was modified in this audit.**
