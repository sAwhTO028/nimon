# M23A-0 — Learning English Expansion Audit

**Phase:** M23A-0 (investigation only)  
**Scope:** Nimon Flutter app + NestJS backend + HTML/JSON generator tools  
**Constraint:** No code, migrations, UI, validation, generator, publish, or feed behavior changes in this phase.

**Product target (future):** `learningLanguage=en` with `contentLocale ≠ en` (e.g. `en+my`), distinct pair invariant preserved; Japanese furigana/ruby/kanji rules must not apply to English learning content.

---

## A. Executive summary

1. **V1 today is Japanese-learning only at the product gate:** `LEARNING_LANGUAGES = ['ja']` (backend DTO), Settings UI offers only `ja` (+ disabled “More languages”), and import blocks `NimonLearningLanguage.english` with `import.context.englishComingSoon`.
2. **Pair rule is already generic:** `assertDistinctLanguagePair` / `isSameLanguagePair` block same wire code (`ja+ja` today; would block `en+en` once `en` is in the learning type).
3. **English cannot be enabled safely today** without coordinated changes: publish/HTML validation hardcodes `HtmlLearningLanguage.jp` / `'jp'`, furigana validation runs on all vocab rows with kanji heuristics, and catalog feed forces stored `learningLanguage` to `ja` via `safeStoredLearningLanguage`.
4. **Config groundwork exists:** `HtmlGeneratorLimits` (Flutter + backend) and generator HTML v8+ include **JP and EN** limit tables; generator UI can select English learning and disables matching content community (e.g. English community when learning English).
5. **Import enum already has English** (`NimonLearningLanguage.english` → wire `en`); mapper can write `basics.learningLanguage` from meta, but validator rejects English before a successful import.
6. **Draft/publish DTOs reject `learningLanguage: 'en'`** on write (`@IsIn(['ja'])`); DB columns are nullable `TEXT` (no Prisma enum) — storage-compatible, but API normalization on publish coerces unknown learning codes to `ja`.
7. **Sentence/vocab wire models are Japanese-named** (`japaneseText`, `termJapanese`, `furiganaSpans`) but furigana is **optional** at publish for surfaces without kanji; full-learn still applies **Japanese-oriented** HTML count rules and vocab field names.
8. **Learn module LM1 is “Vocabulary / Kanji”** (`LearnModuleId.vocabularyKanji`); editor requires furigana UI for Japanese sentences; grammar examples use `jp` fields — English needs conditional UX and naming.
9. **Feed/public collections (M22E)** filter on `contentLocale` + `learningLanguage` with `CatalogLearningLanguage = 'ja'` only; hypothetical `en+my` published mono would not match a viewer whose effective learning is coerced to `ja`.
10. **M22F collection add rule** checks **contentLocale only** — still correct for `learningLanguage=en` + `contentLocale=my` monos into `my` collections; no change required for that rule alone.

### Main blockers (enable `learningLanguage=en` in production)

| ID | Blocker |
|----|---------|
| B1 | Backend + Flutter preferences allow-list: `ja` only |
| B2 | Publish + import validation: HTML rules language hardcoded to JP |
| B3 | Full-learn furigana/kanji validators not conditional on `learningLanguage` |
| B4 | Catalog `safeStoredLearningLanguage` / query allow-list: `ja` only |
| B5 | Publish stamping `resolvePublishLanguageTags` → `normalizeV1LearningLanguage` drops `en` to `ja` |
| B6 | Import `englishComingSoon` gate |
| B7 | Settings UI + draft write DTO: no selectable / persistable `en` |

**Verdict:** English learning is **not safe to enable** end-to-end today. Partial enable (e.g. prefs only) would create inconsistent stamps, feed mismatches, and wrong publish limits.

---

## B. Current language standard

| Concept | Wire / storage | Allowed values (V1 product) | Notes |
|---------|----------------|------------------------------|-------|
| **Learning language** | `learningLanguage` | **`ja` only** (product); DB string can hold other values | Target language being learned |
| **Content locale / community** | `contentLocale` | `en`, `my`, `ja` | Community / explanation language |
| **Forbidden pair** | same code on both axes | `learningLanguage === contentLocale` | e.g. `ja+ja`, future `en+en` |
| **Not in V1** | `commonLanguage`, `sourceLanguage` | — | No repo usage (M22D audit) |
| **App locale** | `appLocale` | `system`, `en`, `ja`, `my` | UI language; independent of learning pair |

**Canonical helpers**

- Backend: `language-pair-validation.ts` — `V1ContentLocale`, `V1LearningLanguage = 'ja'`, `assertDistinctLanguagePair`, `resolvePublishLanguageTags`
- Flutter: `language_pair.dart` — `isSameLanguagePair`, `languagePairBlockedMessage()`
- Content community labels: `content_community.dart` — Myanmar / International English / Japanese

---

## C. Flutter Settings / Preferences current state

### UI (`settings_screen.dart`)

| Question | Finding |
|----------|---------|
| Where displayed? | Settings → Language section: “Learning language” `ListTile` with subtitle |
| Only Japanese selectable? | **Yes** — dialog offers `_radio(..., value: 'ja')` only |
| English coming soon? | **Yes** — disabled `ListTile` “More languages” + `settingsComingSoon` subtitle |
| Label for `en` if returned? | `_learningLanguageLabel` maps any code → **“Japanese”** (no `en` branch) |
| Content community vs learning | Picker **hides `ja`** when `learningLanguage=ja`; blocks pick via `isSameLanguagePair` + snackbar |
| Hide `en` when learning `en`? | **Not implemented** (only `ja` hidden for `ja` learning) — needed when enabling English |

### Model (`user_preferences_repository.dart`)

- `UserPreferences.learningLanguage` comment says `// ja` but field is plain `String`.
- `_parsePreferences`: **no allow-list** on `learningLanguage` — if API returns `en`, Flutter **will display/store it** in state (subtitle still shows “Japanese” due to label helper).
- PATCH sends arbitrary string in JSON body; server rejects non-`ja`.

### Patch / refresh (`user_preferences_notifier.dart`)

| Preference change | Home / following feed refresh? | Public profile | Own profile lists | Workspace / saved |
|--------------------|--------------------------------|----------------|-------------------|-------------------|
| `contentLocale` | **Yes** — `monoFeedPagerProvider` + `followingMonoFeedPagerProvider` | Public profile: reloads collections when tab 1 active (`public_profile_screen.dart` listen) | **No explicit refresh** in notifier | **No** |
| `learningLanguage` | **Yes** — same feed refresh | Public profile: same listen (locale **or** learning change) | **No explicit refresh** | **No** |

Feed repo does not pass `learningLanguage` query params from client — server resolves from prefs (see §I).

---

## D. Import / JSON / generator current state

### Import enums & meta

| Item | Status |
|------|--------|
| `NimonLearningLanguage` | `japanese`, **`english`**, `unknown` |
| Wire mapping | `japanese` → `ja`, **`english` → `en`** |
| JSON `learningLanguage` strings | `"Japanese"`, `"English"`, etc. via `nimonLearningLanguageFromString` |
| English rejected? | **Yes** — `_validateAppContext`: `import.context.englishComingSoon` then **return** |
| Account match | Requires import learning = prefs learning; content community = prefs `contentLocale` |
| Same pair | **Yes** — `import.context.languagePairSameNotAllowed` via `isSameLanguagePair` |

### HTML rules path in import (`nimon_import_validator.dart`)

- Maps meta to `HtmlLearningLanguage.jp` | `en`.
- If `en`: **early return** before sentence/vocab/quiz HTML rule checks (lines ~302–305) — no false failures from JP limits, but import still blocked earlier by `englishComingSoon`.
- Full-learn shape validation (vocab/grammar/quiz lists) still runs for Japanese imports.

### Mapper (`nimon_import_mapper.dart`)

- Can set `StoryBasics.learningLanguage: meta.learningLanguage.preferencesWireCode` (**including `en`** if validator were opened).

### Generator tools (`tool/html_generator/Json_Generator_*.html`)

| Capability | JP | EN |
|------------|----|----|
| Learning language select | Yes | Yes (v8+) |
| `updateContentCommunity()` | Disables Japanese community if learning Jp | **Disables English community if learning En** |
| Prompt output | Japanese-centric story rules | Separate EN limit tables in shared config |
| `commonLanguage` / `sourceLanguage` in output | **Not required** — not in V1 import schema |

### Japanese-specific import/publish assumptions

- Sentence body keys: `japaneseText` (+ legacy aliases in metrics extractors).
- Vocab: `termJapanese`, `reading`, kanji type, furigana spans on sentences.
- Grammar/quiz: JLPT level keys (`N5/A1` …) used for **both** JP and EN HTML limit tables today.
- Furigana: kana regex validation when kanji present — irrelevant for pure Latin English terms unless validators are gated.

### English gaps

- Remove / replace `englishComingSoon`.
- Wire publish/import validation to **`HtmlLearningLanguage.en`** from draft/meta, not hardcoded `jp`.
- Define English story JSON shape (still use `japaneseText` vs rename — product decision).
- English full-learn: which modules, counts, and whether kanji module exists.

---

## E. Draft / Story model current state

### Structural support

| Layer | `learningLanguage=en` | `contentLocale` |
|-------|-------------------------|-----------------|
| `StoryBasics` / `CreatorStoryV1` | Optional `String?` — **no enum constraint** | Optional `String?` |
| `story_draft_dto` / wire | Strings on wire | Same |
| Backend `StoryDraft` Prisma | `learningLanguage String?` | `contentLocale String?` |
| Create/update DTO | **`@IsIn(['ja'])` only** | `@IsIn(['en','my','ja'])` |

Comment in `story_v1_model.dart` still says “V1: `ja`” for `learningLanguage`.

### Japanese-only / Japanese-named fields (should be conditional for English)

| Area | Fields / behavior |
|------|-------------------|
| Sentences | `japaneseText`, `reading`, `furiganaSpans`, `FuriganaSpan` |
| Vocab (LM1) | `termJapanese`, `reading`, `VocabularyKanjiEntryType.kanji`, pick-from-story furigana helpers |
| Grammar | `headline`, examples with `japanese` / `jp` controllers |
| Quiz | Categories Vocabulary / Grammar / Sentence — generic structure |
| Audio | URL/asset — **language-agnostic** |

### Furigana / ruby at publish

- **Not required** for sentences at publish gate (optional in model; M21B matrix).
- **Required for vocab** when `isKanjiType` or surface contains kanji (`validateFuriganaReading` / `validateFurigana`) — **not gated by `learningLanguage`** → English Latin terms typically skip reading requirement, but kanji heuristic could still fire on mixed text.

---

## F. Learn modules current state

| Module | ID / label | Japanese-specific? | English notes |
|--------|------------|--------------------|---------------|
| **LM1** | `vocabularyKanji` / **“Vocabulary / Kanji”** | **Yes** — kanji type, reading, furigana pick from story | Rename/hide Kanji; optional reading |
| **LM2** | `grammar` | Partial — pattern title + JP example lines | Schema may reuse; labels “Japanese” in UI |
| **LM3** | `quiz` | Low — question/options generic | Count rules tied to JP HTML tables today |
| **LM4** | `audio` | No | Same for English |
| Listening / pronunciation | No separate module beyond audio in V1 | — | — |

**Backend** learn publish loop always runs `validateFuriganaReading` for vocab rows with non-empty `termJapanese` (see `publish-validation.ts` ~542–551).

**Readiness (Flutter)** `creator_completion_rules.dart` / `creator_readiness.dart` — duration-based minimums for vocab/grammar/quiz; not language-aware.

---

## G. Backend preferences / validation current state

| File | Behavior |
|------|----------|
| `me-preferences.dto.ts` | `LEARNING_LANGUAGES = ['ja']`; PATCH `@IsIn(LEARNING_LANGUAGES)` |
| `auth.service.ts` | `assertDistinctLanguagePair(safeV1ContentLocale, safeV1LearningLanguage)` on PATCH |
| `language-pair-validation.ts` | `normalizeV1LearningLanguage`: **only `ja`**; unknown → null → default `ja` |
| `getMePreferences` | `resolvePreference` returns **raw DB string** without learning allow-list sanitize (unlike `readingTextSize`) — orphan `en` in DB could surface on GET |
| Tests | `me.profile.controller.spec.ts`: PATCH `learningLanguage: 'en'` → **400** |

**Adding `en` safely (prefs layer):**

1. Extend `LEARNING_LANGUAGES`, `V1LearningLanguage`, `normalizeV1LearningLanguage`, `CatalogLearningLanguage`.
2. Sanitize GET/PATCH responses with `safeV1LearningLanguage` (or equivalent).
3. Extend `language-pair-validation.spec.ts` with `en+my` allowed, `en+en` rejected.
4. Settings Flutter: selectable `en`, hide `en` in content community when learning `en`.

---

## H. Backend publish / readiness validation current state

| Check | Conditional on `learningLanguage`? | Issue for English |
|-------|-----------------------------------|-------------------|
| Title / description | No | OK |
| `extractStorySentenceMetrics` / `japaneseText` keys | No | English text can live in same keys; metric name misleading |
| HTML sentence limits | **`language: 'jp'` hardcoded** (`publish-validation.ts` ~240) | **Wrong limits for EN** |
| HTML vocab/grammar/quiz counts | **`jp` hardcoded** | **Wrong counts** |
| `validateFuriganaReading` | **No** | Usually OK for Latin; must skip for EN policy |
| JLPT `normalizeHtmlLevel` | No | EN generator uses same JLPT/CEFR bands in config |
| Full-learn module completion | No | OK |
| `resolvePublishLanguageTags` | Coerces learning to **`ja`** | **BLOCKER** for stamping `en` |

**Flutter mirror:** `publish_validation.dart` uses `HtmlLearningLanguage.jp` throughout (~289, 351, 356).

**Read-only publish:** Still applies JP HTML sentence rules — English read-only would fail or mis-validate without EN branch.

---

## I. Feed / collections / saved / profile current state

### `published_mono_catalog_locale.ts`

- `CatalogLearningLanguage = 'ja'`.
- `ensureAllowedLearningLanguageQuery`: only `ja` or 400.
- `safeStoredLearningLanguage`: non-`ja` stored values → **`ja` fallback**.
- `publishedMonoCatalogLocaleWhere`: filters `learningLanguage` = effective (**`ja`** for almost all viewers).

### Mono feed (`mono-feed.service.ts`)

- Uses `resolveCatalogLanguageContext` — same as public collections (M22E parity).

### Published mono schema

- `PublishedMono.learningLanguage` / `contentLocale`: **nullable String** (indexed together).
- No migration required to **store** `en`; product gates prevent correct lifecycle.

### Collection add rule (M22F-2)

- `assertCollectionContentLocaleCompatible` — **`contentLocale` only**.
- `learningLanguage=en`, `contentLocale=my` mono → add to `my` collection: **allowed** (and correct).

### Owner / saved surfaces

- M22F-1 exposed `contentLocale` / `learningLanguage` on list DTOs for badges.
- **No `learningLanguage` filter** on own profile published/workspace/saved lists today.
- Public profile collections reload on prefs change; **mono list providers** on own profile do not auto-refresh on learning change.

### Feed case `en+my` viewer + `en+my` mono

- Today: viewer effective learning **`ja`** (prefs default + safe store) → mono with `learningLanguage=en` **hidden** unless null legacy row matches OR clause.

---

## J. Database compatibility

| Question | Answer |
|----------|--------|
| Fields string-based? | **Yes** — `UserPreference`, `StoryDraft`, `PublishedMono` |
| Prisma enums for language? | **No** |
| Migration to add `en`? | **Not strictly required** for storage |
| Default / backfill | Historical rows: `learningLanguage` null or `ja` (migrations set draft/published defaults to `ja`) |
| Indexes | `(contentLocale, learningLanguage, updatedAt)` on `published_monos` — still valid for `en` |
| Risk | Orphan or manual `en` in DB without API support → feed coercion to `ja`, publish stamp to `ja` |

---

## K. Current behavior matrix

| Case | Pair / input | Expected **today** | Notes |
|------|----------------|-------------------|-------|
| **A** | `learningLanguage=ja`, `contentLocale=my` | **Allowed** | Default product pair; feed/catalog match |
| **B** | `learningLanguage=ja`, `contentLocale=en` | **Allowed** | Pair rule OK |
| **C** | `learningLanguage=ja`, `contentLocale=ja` | **Blocked** | PATCH `language_pair_same_not_allowed`; Settings UI blocks |
| **D** | `learningLanguage=en`, `contentLocale=my` | **Rejected** (prefs) / **not product-available** | PATCH 400; UI cannot select `en` |
| **E** | `learningLanguage=en`, `contentLocale=en` | **Blocked** (if `en` were allowed) | Pair rule; generator disables English community when learning En |
| **F** | Import `learningLanguage=English`, `contentCommunity=Myanmar` | **Rejected** | `import.context.englishComingSoon` before mapper apply |
| **G** | Draft `learningLanguage=en`, no furigana | **Rejected at API save** | DTO `@IsIn(['ja'])`; local-only possible but non-standard |
| **H** | Publish full-learn English, no furigana/kanji | **Rejected or wrong** | Import blocked; if forced: publish stamps **`ja`**, JP HTML limits, vocab furigana rules may pass Latin but counts wrong |
| **I** | Feed user `en+my`, mono `en+my` | **Hide** (effective learning `ja`) | `safeStoredLearningLanguage` → viewer sees `ja+my` catalog |
| **J** | Collection `contentLocale=my`, mono `en+my` | **Add allowed** | M22F checks content locale only |

---

## L. Risks / blockers

| Risk | Class | Description |
|------|-------|-------------|
| `LEARNING_LANGUAGES = ['ja']` only | **BLOCKER** | Cannot set prefs or validate PATCH for `en` |
| `normalizeV1LearningLanguage` / publish stamp | **BLOCKER** | Published monos get `ja` even if draft had `en` |
| Publish/HTML validation hardcoded `jp` | **BLOCKER** | Wrong gates for English content |
| Import `englishComingSoon` | **BLOCKER** | No JSON import path for English |
| Draft DTO `@IsIn(['ja'])` | **BLOCKER** | Cannot persist `en` via API |
| `CatalogLearningLanguage = 'ja'` + safe store | **HIGH** | Feed/collections hide English-learning monos |
| Furigana validators not conditional | **HIGH** | Japanese rules may still apply to mixed content; policy unclear for EN |
| Settings UI / labels | **HIGH** | No `en` selection; wrong label if API returns `en` |
| Sentence editor / furigana UX | **HIGH** | Japanese-first copy and furigana management |
| LM1 “Vocabulary / Kanji” naming | **MEDIUM** | Product/UX debt for English |
| `japaneseText` / `termJapanese` field names | **MEDIUM** | Confusing contract for English JSON |
| Flutter `publish_validation` JP hardcode | **BLOCKER** (client preflight) | Publish button fails before server |
| GET prefs no learning sanitize | **LOW** | Raw `en` in DB could leak to client |
| Content community picker hide `en` for `en` learning | **MEDIUM** | Not implemented (only `ja` hide today) |
| Own profile no refresh on learning change | **MEDIUM** | Stale lists until manual navigation |
| Tests assume `ja` only | **MEDIUM** | Broad spec updates needed |
| HTML generator EN prompts incomplete vs JP | **MEDIUM** | Tooling ahead of app validation |
| `commonLanguage` / `sourceLanguage` | **LOW** | Absent — do not add without product spec |

---

## M. Recommended implementation roadmap

**Do not implement in M23A-0.** Suggested sequencing:

### M23A-1 — Preferences & pair validation only

- Extend `LEARNING_LANGUAGES`, `V1LearningLanguage`, Flutter Settings (`en` radio, hide `en` community when learning `en`).
- Sanitize GET preferences with `safeV1LearningLanguage`.
- Tests: `en+my` OK, `en+en` fail, PATCH/GET round-trip.
- **No** publish/import/feed changes yet (feature flag or internal-only).

### M23A-2 — Draft / import metadata for `en`

- Draft DTO `@IsIn(['ja','en'])`; Flutter draft save accepts `en`.
- Remove `englishComingSoon`; align import context checks.
- Import HTML rules: run **EN** tables when meta is English (remove early return skip).
- Pair validation on draft basics + import meta.

### M23A-3 — Generator prompt rules for English learning

- Finalize EN prompt templates in `tool/html_generator` (v8/v9 parity).
- Document JSON field contract for English sentences/vocab.
- Optional sample EN import JSON for QA.

### M23A-4 — Conditional furigana / ruby / kanji validation

- Pass `learningLanguage` into `validateStoryPublishInput` / Flutter `validateStoryPublishData`.
- When `en`: skip `validateFuriganaReading`, kanji type requirements, sentence furigana UI validation.
- Use `HtmlLearningLanguage.en` for HTML limits when `learningLanguage=en`.
- Backend + Flutter parity tests.

### M23A-5 — Learn module UI labels (English)

- Rename LM1 display (“Vocabulary” only?), hide Kanji segment for `en`.
- Sentence editor: hide furigana manager; relabel “Japanese sentence” copy.
- Grammar sheet: English example labels vs `jp` field reuse.

### M23A-6 — Feed / collection / saved / profile multi-learning

- `CatalogLearningLanguage` + `safeStoredLearningLanguage` include `en`.
- Feed query param allow `en`.
- Decide owner/public list filtering policy (product).
- Refresh own profile lists on learning change (optional).

### M23A-7 — Tests & sample English import

- E2E: prefs `en+my` → import → publish read-only → publish full-learn (no furigana).
- Feed visibility `en+my` mono.
- Collection add J case regression.

---

## N. Files likely to modify

### Backend

- `nimon-backend/src/modules/auth/dto/me-preferences.dto.ts`
- `nimon-backend/src/modules/auth/auth.service.ts`
- `nimon-backend/src/modules/auth/me.profile.controller.spec.ts`
- `nimon-backend/src/common/validation/language-pair-validation.ts`
- `nimon-backend/src/common/validation/language-pair-validation.spec.ts`
- `nimon-backend/src/modules/story-drafts/dto/story-draft.requests.ts`
- `nimon-backend/src/modules/story-drafts/story-drafts.service.ts`
- `nimon-backend/src/common/validation/publish-validation.ts`
- `nimon-backend/src/common/validation/publish-validation.spec.ts`
- `nimon-backend/src/common/validation/learn-validation.ts`
- `nimon-backend/src/common/validation/publish-html-rules-validation.spec.ts` (and module if split from publish-validation)
- `nimon-backend/src/common/limits/html-generator-limits.ts`
- `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.ts`
- `nimon-backend/src/modules/published-monos/published-mono-catalog-locale.spec.ts`
- `nimon-backend/src/modules/mono-feed/mono-feed.service.ts`
- `nimon-backend/src/modules/creator-collections/creator-collections.service.ts` (only if policy extends beyond contentLocale)

### Flutter

- `lib/features/settings/settings_screen.dart`
- `lib/features/settings/data/user_preferences_repository.dart`
- `lib/features/settings/presentation/providers/user_preferences_notifier.dart`
- `lib/core/settings/language_pair.dart`
- `lib/core/settings/content_community.dart`
- `lib/features/create/import/nimon_import_enums.dart`
- `lib/features/create/import/nimon_import_validator.dart`
- `lib/features/create/import/nimon_import_mapper.dart`
- `lib/features/create/import/nimon_hidden_json_import_flow.dart`
- `lib/features/create/story_v1_model.dart` (comments / optional English helpers)
- `lib/features/create/data/dto/story_draft_dto.dart`
- `lib/features/create/data/story_draft_mapper.dart`
- `lib/core/validation/publish_validation.dart`
- `lib/core/validation/learn_validators.dart`
- `lib/core/limits/html_generator_limits.dart`
- `lib/features/create/story_creator_sentences_screen.dart`
- `lib/features/create/story_creator_vocab_kanji_editor_screen.dart`
- `lib/features/create/story_creator_grammar_editor_screen.dart`
- `lib/features/create/creator_progress_drawer.dart`
- `lib/features/create/creator_completion_rules.dart`
- `lib/features/create/creator_readiness.dart`
- `lib/features/profile/public_profile_screen.dart` (refresh policy)
- `lib/features/profile/profile_screen.dart` (optional own-profile refresh)

### Generator tools

- `tool/html_generator/Json_Generator_ImportReadyPrompt_v8_strict_import_precheck.html`
- `tool/html_generator/Json_Generator_ImportReadyPrompt_v9_json_based_precheck.html`

### Tests (representative)

- `test/features/create/nimon_import_validator_test.dart`
- `test/features/create/nimon_import_html_rules_validator_test.dart`
- `test/features/create/nimon_import_full_learn_flow_test.dart`
- `test/features/create/nimon_import_publish_readiness_test.dart`
- `test/core/validation/publish_validation_gate_test.dart`
- `test/core/validation/publish_html_rules_validation_test.dart`
- `test/features/create/creator_html_rules_readiness_test.dart`
- `nimon-backend/src/common/validation/publish-validation.spec.ts`

---

## O. Product questions

1. **V1 vs coming soon:** Should English learning be fully shippable in V1, or Settings-only “coming soon” until M23A-4/6 complete?
2. **Kanji replacement:** For English LM1, is it “Vocabulary” only (no kanji type), or a new module (e.g. phrases/idioms)?
3. **LM1 naming:** Rename to “Vocabulary” globally or only when `learningLanguage=en`?
4. **Furigana:** Confirm **fully absent** for English (no optional ruby)—including import JSON and reader display?
5. **Grammar schema:** Reuse JP-shaped grammar entries (headline + examples) with English sentences in `japanese` fields, or new English grammar shape?
6. **Allowed communities for English learning:** `my` + `ja` only, or also `en` international explanations with `en` learning blocked—confirm `en+ja` future intent?
7. **Level bands:** Keep JLPT/CEFR combined levels for English stories or introduce English-only level scale?
8. **Sentence wire field:** Keep `japaneseText` for English primary text vs introduce `primaryText` / `englishText` alias?
9. **Feed/profile filtering:** Should own profile / saved / workspace filter by **both** `contentLocale` and `learningLanguage`, or only community?
10. **Legacy monos:** How to surface `learningLanguage=null` after multi-learning launch (continue OR-null inclusion)?

---

## References (prior audits)

- `docs/M21B_CURRENT_RULE_MATRIX_AUDIT.md` — publish/learn numeric matrix (Japanese-centric)
- `docs/M22D0_CURRENT_LANGUAGE_FEED_PUBLISH_FLOW_AUDIT.md` — feed + stamp flow
- `docs/M22F0_LANGUAGE_FLAGS_AND_COLLECTION_COMMUNITY_AUDIT.md` — owner badges + collections
- `docs/M22F2_COLLECTION_COMMUNITY_AND_ADD_RULE_REPORT.md` — `contentLocale` add rule

---

*Generated for M23A-0. Investigation only; no application code changed.*
