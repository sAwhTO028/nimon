# Nimon V1 Release Priority Plan

## 1. Executive Summary

Nimon today is a **demo-ready Flutter client** with a **focused NestJS + Postgres backend** for story drafts and published monos. Product rules and engineering expectations are **well documented** (`NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md`, `NIMON_CONTENT_LIFECYCLE_AUDIT.md`, runbooks in `DEV_RUN_COMMANDS.md`). **Automated quality gates are green** for the repo as last verified: Flutter **87** tests passing, Nest **`story-drafts.service`** unit tests passing, **`nest build`** success, Prisma **migrate status** up to date on the verified environment (`LOCAL_DB_FINAL_VERIFICATION_REPORT.md`).

**Before a credible V1 release**, the team must close the gap between **“works on my machine with the right flags”** and **a single, predictable production story**: **real accounts / auth** (today the backend `AuthModule` / `UsersModule` are stubs and the login screen is UX-only), **deciding the default authoring mode** (local-first vs remote sync — default Flutter is **local-only**, so Postgres does not reflect creator edits unless remote draft mode and successful API calls), **owner identity alignment** (`NIMON_DEV_OWNER_ID` vs backend `DEV_OWNER_ID` — misalignment yields empty Profile → Published), **API contract parity** where noted (full draft GET type omits `hasUnpublishedCoreChanges` per audit), and **manual / staging E2E** completion (smoke checklist in the DB verification report remains unchecked). Analyzer noise (**~227** infos/warnings, no `error` severity in the reported run) should be triaged for CI policy.

---

## 2. Current Stable Foundation

What is already strong:

- **Architecture docs** — Lifecycle standard, behavioral audit, dev run commands, and README clarify local vs remote draft modes, Prisma Studio expectations, and `dart-define` flags.
- **Cleanup / archive** — Reports (`PUBLISHED_TAB_REFRESH_FIX_REPORT.md`, `DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md`, `LOCAL_DB_FINAL_VERIFICATION_REPORT.md`) record fixes and verification without leaving ambiguous “mystery” behavior for Profile/Published.
- **Remote draft mode** — Compile-time `NIMON_USE_REMOTE_DRAFTS` toggles `LocalStoryDraftRepository` vs `RemoteStoryDraftRepository`; strict mode surfaces integration failures (`NIMON_STRICT_REMOTE_DRAFTS`).
- **Draft summary API** — List summaries carry `hasUnpublishedCoreChanges` and `workspaceState` (including `synced`) on `GET /v1/story-drafts`; Flutter `DraftListSummaryDto` maps conservative defaults for legacy payloads (`DRAFT_DIRTY_STATE_IMPLEMENTATION_REPORT.md`).
- **Pagination foundation** — Profile uses pagers for workspace drafts and published monos; refresh wiring after publish was fixed so Published refetches in remote mode (`PUBLISHED_TAB_REFRESH_FIX_REPORT.md`); tests exist for published pager behavior per that report.
- **Profile Published / Workspace** — Backend-backed published rows stay visible while editing; duplicate hide rules align with `effectiveDraftListWorkspaceState == 'editing'`; synced rows excluded from Processing list per V1 rules.
- **Dirty state** — `story_drafts.hasUnpublishedCoreChanges` in Prisma; migration applied in verified DB; server rules on create/update/publish documented in the dirty-state report.
- **Local DB verification** — Migrations applied, `prisma generate` OK, Jest and Flutter tests passed in the recorded run; column presence for dirty flag confirmed in DB.
- **Tests** — Flutter suite **87** tests passing; Nest **`story-drafts.service.spec.ts`** extended for list mapping / dirty / synced cases per reports.

---

## 3. Current Release Readiness Estimate

Subjective percentages for **V1-shaped release** (demo vs production-grade):

| Area | Estimate | Notes |
|------|------------|--------|
| **Architecture / foundation** | **82%** | Strong docs + verified DB/build/tests; open gaps are operational (staging/prod migrate deploy, CI analyze policy). |
| **Create / publish flow** | **68%** | End-to-end exists for remote path + publish endpoints; default local-only mode vs release expectation; full GET DTO parity and PUT `publishState: 'draft'` semantics need product/test closure per audit. |
| **Profile Published / Workspace** | **76%** | Dirty flag, pagination, refresh-after-publish; still sensitive to owner-id alignment and remote mode. |
| **Mono feed / reader** | **58%** | Rich reader UI and structured content path; feed/collections still described as **V1 mock** and not fully wired to Profile folders (`mono_screen.dart` commentary). |
| **Learn modules** | **52%** | Multiple learn screens and flows present; quiz mock bank and creator/learn wiring imply partial integration vs full server-backed learn product. |
| **Auth / account** | **22%** | Login is navigation-only; `devCurrentUserProvider`; backend auth/users modules empty shells; schema notes optional email for V1. |
| **Saved / collections** | **30%** | In-memory / demo-style saved behavior in Mono scope; not integrated as durable server collections. |
| **Localization** | **38%** | `flutter_localizations` + `intl` in `pubspec.yaml`; no project ARB catalog found — UI strings largely inline English/Material defaults. |
| **Release readiness overall** | **55%** | Strong engineering core for drafts/publish + tests; weakest on identity, persistence of social/collection features, and production config discipline. |

---

## 4. Top Current Risks

1. **No real authentication or multi-tenant safety** — Cannot ship a trustworthy production service until sessions, ownership, and API authorization replace dev UUIDs and stub modules.
2. **Default authoring is device-local** — Creators and operators may assume Postgres reflects edits; it does not without remote drafts and successful sync — risks wrong QA conclusions and “missing data” incidents (`NIMON_CONTENT_LIFECYCLE_AUDIT.md` §8).
3. **Owner / API alignment** — `DEV_OWNER_ID` vs `NIMON_DEV_OWNER_ID` mismatch produces **empty Published** despite successful publish — easy to misread as a product bug (`README.md`, `DEV_RUN_COMMANDS.md`).
4. **Contract and behavior edges** — Full draft GET omits `hasUnpublishedCoreChanges` in the declared DTO; remote PUT forces `publishState: 'draft'` before conditional republish — both require maintainer discipline and regression coverage per audit.
5. **Divergence under remote failure** — Without strict remote mode, device can be ahead of server; readers on other devices see stale content (`NIMON_CONTENT_LIFECYCLE_AUDIT.md` §8).
6. **Incomplete manual E2E** — Automated checks passed; human smoke checklist in `LOCAL_DB_FINAL_VERIFICATION_REPORT.md` still unchecked — staging/prod not verified in that report.
7. **Analyzer debt** — Large info/warning count may fail stricter CI; not compile-breaking in the reported run but adds merge/release friction.

### Output summary

- **Release readiness percentage:** **~55%** (overall V1 release-shaped readiness).
- **Strongest completed area:** **Architecture / documentation + draft–publish backend behavior + automated test suite** (lifecycle standard, audit, dirty flag, story-drafts/published-monos modules, 87 Flutter tests + Nest unit tests passing in verification reports).
- **Weakest area:** **Auth / account** (stub backend modules, demo login, dev-only user identity).
- **Biggest blocker:** **Absence of production-grade authentication, authorization, and a pinned “authoritative sync” story for releases** (who owns content, which build flags apply, and how server state stays consistent with user expectation across devices).

---

## 5. Release Blocking Areas

Classifications use **BLOCKER** (cannot ship a trustworthy production app without addressing), **HIGH** (major product gap or major reliability risk), **MEDIUM** (material gap or debt that can ship with scope cuts / mitigations), **LOW** (polish, deferrable, or demo-tolerable).

### Production auth / account identity — **BLOCKER**

- **Current state:** Flutter login navigates without credentials; `devCurrentUserProvider` supplies a dev identity; Nest `AuthModule` / `UsersModule` are empty placeholders; Prisma `User` exists with optional `email` (“auth is not implemented yet”). Owner scoping for APIs still assumes a known `ownerId` / dev UUID alignment.
- **Release risk:** No session security, no multi-user isolation, no password recovery—**not safe for public production**. Any “release” without this is a **demo / closed beta** with manual trust boundaries only.
- **Recommended action:** Implement real auth (session/JWT or equivalent), persist users, secure draft/published routes by authenticated `ownerId`, remove reliance on `DEV_OWNER_ID` / `NIMON_DEV_OWNER_ID` alignment for normal users, and define guest vs registered behavior.

### Published content read-ready / learn-ready — **HIGH**

- **Current state:** `publishReadOnly` / `publishFullLearn` update `published_monos` and draft flags per lifecycle standard; Profile → Published lists remote rows; Mono reader can consume structured content from published core via mappers (`published_mono_detail_parser.dart`, `MonoContent`). Learn surfaces exist in Flutter (`lib/features/learn/**`) with mixed mock/server depth per prior estimates.
- **Release risk:** Readers may hit **inconsistent** learn gating or incomplete module payloads versus wireframe expectations; “full learn” vs read-only paths need explicit QA per story.
- **Recommended action:** Define a **minimum reader contract** for V1 (read-only vs full learn open); align API payloads with `NIMON_API_QUERY_CONTRACT.md` detail DTOs where drill-in occurs; run targeted E2E on open-from-Published → reader → learn entry.

### Mono feed backend integration — **HIGH**

- **Current state:** Mono UI is substantial; feed slices (For You, Following, Saved) use **mock / in-memory** datasets and seeds (`mono_screen.dart` notes reader-only collections not wired to Profile folders). `NIMON_API_QUERY_CONTRACT.md` defines cursor pagination and `MonoFeedSummaryDto`—not fully backed by a dedicated public feed module in the inspected Nest layout (story-drafts + published-monos exist; catalog feed route is specified as documentation target).
- **Release risk:** **Discovery and reading from the open catalog** do not match production expectations; StoryRepo legacy shapes vs contract require facades.
- **Recommended action:** Add Nest **catalog/feed** endpoints conforming to §1–2 of the query contract; Flutter repository maps pages into `MonoFeedItem` / structured content; retire or narrow mock feeds behind a feature flag.

### Published Mono detail view — **MEDIUM**

- **Current state:** Parsing and mapping from published `content` JSON into reader models exists; Profile navigation opens reader flows with `PublishedMonoAccess` for learn gating. Full “detail” fetch may combine list row + content parsing paths depending on entry point.
- **Release risk:** Edge cases (large content, partial JSON, missing tokens) can break reader UX if not covered by tests; **not** an existential blocker if list → reader path is stable.
- **Recommended action:** Freeze a **detail-load contract** (single GET by mono id per query doc §5); add golden tests on parser + reader shell for representative payloads.

### SQLite / Drift local draft migration — **MEDIUM**

- **Current state:** Creator drafts default to **SharedPreferences** (`StoryCreatorDraftStorage`); no Drift/sqflite dependency in `pubspec.yaml`; “drift” in codebase appears in **session/UI** wording, not the database package.
- **Release risk:** Large drafts, offline queues, and migration tools are harder with prefs; **not** required to ship if remote draft mode + server truth are acceptable for V1 scope.
- **Recommended action:** Treat as **post-V1 or parallel track**: evaluate Drift only after auth + sync semantics are fixed; if pursued, plan one-time migration from prefs JSON to SQLite with backup/export story.

### ARB localization — **MEDIUM**

- **Current state:** `NIMON_STRING_LOCALIZATION_PLAN.md` recommends gen-l10n **when product approves** pubspec changes; interim `app_strings.dart` optional; many UI strings remain inline.
- **Release risk:** Single-locale demo is viable; **international launch** or App Store language requirements push this toward HIGH for specific markets.
- **Recommended action:** Execute plan phases A→D: inventory, ARB files, screen migration, lint policy—**after** stabilizing chrome-heavy flows (Settings-first order per that doc).

### Reactions / Bookmark / Share — **MEDIUM**

- **Current state:** Mono uses local bookmark notifiers and seeded saved ids; API contract references `likesCount` on summaries; share/copy patterns exist elsewhere in app shell—**no** full server-backed reactions/saved catalog in the inspected backend scope.
- **Release risk:** Social proof and retention features **missing** for a “social reading” product vision; core **read/create/publish** can still demo without them.
- **Recommended action:** Scope V1: **client-only bookmark** + share sheet where acceptable; defer server counts and cross-device saved lists until feed + auth exist.

### Follow system — **HIGH** (for “Following” as real product) / **LOW** (for wireframe demo)

- **Current state:** Following feed is built from **mock** creators and filters (`_followingMockItems`, handle sets)—not a persisted graph.
- **Release risk:** **HIGH** if marketing promises a real social graph; **LOW** if V1 is creator-first and Following stays demo-only with disclaimer.
- **Recommended action:** Product call: ship **mock Following** with label, or implement `follow` edges + API before promising parity with major readers.

### Saved / Collections — **HIGH**

- **Current state:** Mono reader collections are **V1 mock** and explicitly not wired to Profile folder screens; Profile has folder/detail UI surfaces that need durable lists.
- **Release risk:** Users lose “saved” state across reinstalls/devices; Profile folders feel hollow vs Mono seed behavior.
- **Recommended action:** After auth: **`SavedMonoSummaryDto`-style** API (`NIMON_API_QUERY_CONTRACT.md` §4.3) + Flutter sync; unify Mono unsave callbacks with Profile Saved tab.

### Search / filters — **MEDIUM**

- **Current state:** Mono has level chips and content-type modeling; contract defines `query`, `level`, `category` params—backend FTS/index notes are documentation-level until feed service implements them.
- **Release risk:** Poor discoverability at scale; acceptable for small curated beta catalogs.
- **Recommended action:** Ship **minimal** server filters first (`level`, `sort`); defer full-text search until feed indexes exist.

### CI / test gate — **MEDIUM**

- **Current state:** Verification report: tests and build green; `flutter analyze` reports many infos/warnings (non-zero exit in some setups).
- **Release risk:** Flaky or noisy CI blocks velocity; stricter analyze rules may fail until debt is paid.
- **Recommended action:** Triage analyzer buckets; enforce **test + build** on PR; optionally gate `error`-severity only until cleanup passes.

---

## 6. Recommended Implementation Order

Practical order for a **solo developer**, with **one concern per milestone** (no mixing auth, SQLite, localization, and backend feed work in the same milestone).

| Milestone | Focus | Outcome |
|-----------|--------|---------|
| **M1 — Auth & identity** | Sessions, user records, secured `ownerId` on all draft/published routes, login/logout flows replacing dev providers. | Production-trustworthy identity; removes DEV_OWNER_ID footguns for real users. |
| **M2 — Remote authoring as default for release builds** | Release flavor pins `NIMON_USE_REMOTE_DRAFTS` (and docs); strict mode in CI integration where applicable; optional full GET DTO parity for `hasUnpublishedCoreChanges`. | One authoritative sync story aligned with `NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md`. |
| **M3 — Mono catalog API + Flutter facade** | Nest feed/list endpoints per `NIMON_API_QUERY_CONTRACT.md`; cursor pages; map into Mono feed—**no** SQLite work here. | Real discovery path replaces mocks. |
| **M4 — Published reader & learn minimum contract** | Detail GET + reader/learn entry QA; fix gaps between mock learn bank and server payloads where required for V1. | Readers can complete the advertised loop from catalog/profile. |
| **M5 — Saved server model + Profile wiring** | Persisted saved monos/collections API; replace Mono-only seeds with synced lists—**no** auth redesign here (consumes M1). | Durable collections across devices. |
| **M6 — Social layer (follow, reactions)** | Follow edges + counters as needed; align with feed sorting—**separate** from M3 schema churn where possible. | Following tab becomes real or intentionally scoped down. |
| **M7 — ARB / gen-l10n** | Enable codegen per `NIMON_STRING_LOCALIZATION_PLAN.md`; migrate chrome strings Settings → shared → Mono → Create → Profile. | Ship-ready i18n for app UI. |
| **M8 — SQLite/Drift evaluation (optional)** | Only if prefs limits bite: migrate local draft cache—**after** M1–M2 stable sync semantics. | Offline resilience / large draft support. |
| **M9 — CI hardening** | Analyzer policy, smoke E2E checklist automation where feasible. | Repeatable releases. |

Reorder **M7** earlier only if a **market or store requirement** mandates localization before social features.

---

## 7. Next Immediate Milestone

**Pick:** **M1 — Production auth & account identity.**

**Why first:** Every other surface—draft ownership, published lists, saved collections, follow graph, and reaction counts—assumes a **stable, authenticated subject**. Shipping feed or SQLite without identity only postpones rework and perpetuates dev-UUID coupling (`README.md` / `DEV_RUN_COMMANDS.md` owner alignment issues become permanent hacks). The lifecycle standard already distinguishes **draft** vs **PublishedMono** on the server; **who may mutate those rows** must be answered before scaling API or client features.

---

### Output summary

- **Biggest blocker:** **Production auth / account identity** (sessions, real `ownerId`, secured APIs—see §5 first item).
- **Next milestone:** **M1 — Production auth & account identity** (§7).
- **SQLite before release?** **No** for a first **public** V1 if **remote drafts + Postgres** remain authoritative and SharedPreferences limits are acceptable for unsynced edge cases—plan SQLite/Drift as **post-V1 or advanced offline** (§5 SQLite row). For a **private beta**, **no** SQLite required if the cohort accepts the same constraints; widen to **yes / strongly recommended** only when offline durability or draft size forces it—still **after** auth + sync semantics (milestone order §6).
- **GraphQL needed?** **No.** `NIMON_API_QUERY_CONTRACT.md` standardizes **REST**, cursor pagination, and DTOs; current Nest modules follow REST-style controllers—extend catalog routes under the same pattern unless a future separate initiative chooses GraphQL.

---

## 8. SQLite / Drift Migration Plan

### Why SharedPreferences is not enough for drafts

- **Size and churn:** Creator drafts are **large JSON blobs** (basics, many sentences, learn-module payloads, audio metadata). SharedPreferences is designed for **small key–value** flags and forces **read-modify-write of the entire blob** on each save—cost scales poorly with content length (`NIMON_PERFORMANCE_BUDGETS.md`: avoid heavy work in hot paths).
- **No relational integrity:** Sentences and child modules are naturally **row-per-entity**; stuffing them into one string loses cheap partial updates, ordering guarantees, and transactional boundaries.
- **Platform limits:** Very large values risk **slow I/O, memory spikes, and vendor-specific size caps**; debugging corrupted single-string JSON is painful.
- **Sync / offline queues:** A durable **outbox** (pending PUT/publish operations) fits **tables + transactions**; prefs are a poor fit for idempotent replay and crash recovery (`NIMON_CACHE_AND_REFRESH_POLICY.md` §6–§7).

### What stays in SharedPreferences

- **App chrome preferences:** App System Language selection (until synced profile exists), theme toggles, reader font size/theme prefs already used elsewhere.
- **Lightweight feature flags / session hints:** Last-selected tab, non-sensitive UI state, small compile/runtime mirrors (`RemoteBackendConfig` remains compile-time; prefs hold **user** choices only).
- **Optional thin index:** A **small** JSON index of `draftId → {updatedAt, etagHint}` if the team wants a fast listing layer—**or** move index fully into SQLite for one source of truth.
- **Auth token handles** only if the project policy keeps them in prefs (prefer secure storage for secrets—cache doc §2 defers to existing patterns).

### What moves to SQLite / Drift

- **Authoritative local draft body:** Normalized **draft row** + **sentence rows** (or bounded JSON per sentence row) + **module rows** mirroring creator domain (`CreatorStoryV1` shape mapped to tables or structured columns).
- **Debounced write target:** Replace whole-blob prefs writes with **transactional** updates to touched rows.
- **Sync outbox:** Rows for **pending remote operations** (PUT draft, publish POST) with retry counts and last error—supports offline-friendly queue (`NIMON_CACHE_AND_REFRESH_POLICY.md`).
- **LRU or session cache** optional: detail payloads per cache policy can remain memory-first; SQLite backs **durability**, not necessarily every LRU entry.

### Proposed local tables (conceptual)

| Table | Purpose |
|-------|---------|
| **`local_drafts`** | `draftId` (PK), `schemaVersion`, `publishState` enum text, `updatedAt`, `basicsJson` or flattened columns, `moduleWorkflowJson`, sync metadata (`lastLocalVersion`, `lastServerVersion`, `dirty`). |
| **`local_draft_sentences`** | FK `draftId`, `order`, `contentJson` (or normalized columns), `updatedAt`. |
| **`local_draft_children`** | Optional split: vocab/grammar/quiz/audio as typed rows FK `draftId` + `order`/`kind`. |
| **`sync_outbox`** | `id`, `draftId`, `operation` (`putDraft` \| `publishReadOnly` \| `publishFullLearn`), `payloadRef` or inline JSON, `createdAt`, `attempts`, `lastError`. |
| **`draft_local_meta`** | Resume pointers, drawer step hints—only if not duplicated in Riverpod session state. |

Exact normalization level is a **product/engineering tradeoff**: **fully normalized** vs **sentence-level JSON blobs**—both beat a **single giant prefs string**.

### Migration strategy

1. **Ship Drift schema v1** behind feature flag or internal build.
2. **One-time migrator** on first launch: read legacy SharedPreferences keys (`StoryCreatorDraftStorage`), parse JSON, **INSERT** into SQLite in one transaction; **verify** round-trip against a checksum or sample read.
3. **Dual-write window (optional):** write SQLite first, then mirror to prefs until confidence—then delete prefs keys.
4. **Rollback:** keep backup file or last prefs export until migration marked successful (`NIMON_PERFORMANCE_BUDGETS.md`: avoid blocking UI—run heavy migration off critical frame).
5. **Version bumps:** Drift migrations for future columns—never mutate raw files without migration steps.

### Preserve `StoryDraftRepository` interface

- Keep **`StoryDraftRepository`** as the **only** facade for `StoryCreatorDraftNotifier`.
- Replace internals of **`LocalStoryDraftRepository`**: prefs → Drift DAOs; **`RemoteStoryDraftRepository`** unchanged in **contract**—still “local first, then HTTP.”
- Add **integration tests** at repository boundary so Riverpod layers do not churn.

### Risks

- **Data loss** if migration truncates or mis-parses legacy JSON—mitigate with backup + dry-run counts.
- **Complexity** for solo maintainer—defer until prefs pain is proven (`§6` milestone **M8**).
- **Sync divergence:** SQLite must respect same **remote PUT / publish** semantics as today (`NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md`).

### First implementation prompt

> Add Drift to the Flutter project (pubspec + codegen). Implement `LocalStoryDraftRepositoryDrift` backing the existing `StoryDraftRepository` API: migrate legacy `StoryCreatorDraftStorage` SharedPreferences JSON into tables `local_drafts`, `local_draft_sentences`, optional child tables; add `sync_outbox` for queued PUT/publish. Feature-flag the new repository from `storyDraftRepositoryProvider`. Include migration tests: golden prefs fixture → SQLite rows → read equals original domain model. Do not change remote Nest contracts. Follow `NIMON_CACHE_AND_REFRESH_POLICY.md` for outbox replay rules.

---

## 9. Published Content Readiness Plan

### Current publish flow (summary)

- **Flutter:** Creator sets publish state via **`publishReadingOnlyToDisk` / `publishFullLearnToDisk`** paths; **`RemoteStoryDraftRepository.saveDraft`** performs **local persist**, **PUT** `/v1/story-drafts/:id` (with documented `publishState: 'draft'` sequence), then **POST** `/publish/read-only` or `/publish/full-learn` with **`If-Match`** when applicable (`NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md`, `NIMON_CONTENT_LIFECYCLE_AUDIT.md`).
- **Nest:** **`publishReadOnly`** inserts or updates **`published_monos`**, links **`story_drafts.publishedMonoId`**, clears **`hasUnpublishedCoreChanges`**; **`publishFullLearn`** updates metadata on existing published mono + draft learn timestamps.

### What `PublishedMono` must contain for the reader

- **`published_monos.content` JSON** must include a **stable reader core**: title/meta surface fields + **ordered sentence snapshots** compatible with **`plainBodyFromPublishedCore` / `buildMonoContentFromPublishedCore`** (`lib/features/profile/data/published_mono_detail_parser.dart`)—i.e. `core.sentences[]` with sentence `content` shapes that yield Japanese lines and optional structured **`MonoContent`** pages for paginated reading.
- **Learn / access hints:** Enough metadata for **`PublishedMonoAccess`** (or equivalent) so **`MonoScreen`** can decide **Learn entry gating** (`full_learn_published` vs read-only)—today driven by publish state + parsed access from APIs/profile wiring.

### Mono feed requirements

- **Summaries only:** **`MonoFeedSummaryDto`** shape (`NIMON_API_QUERY_CONTRACT.md` §4.1)—**no** sentences, quiz banks, or learn trees in list payloads; **cursor** pagination (`items`, `nextCursor`, `hasMore`, optional `totalCount`).
- **Performance:** Default **`limit` 15**, max **30**; envelope **≤ 512 KB** (`NIMON_PERFORMANCE_BUDGETS.md`).
- **TTL / refresh:** Short freshness or pull-only; **invalidate first page** on publish events, not entire global cache tree (`NIMON_CACHE_AND_REFRESH_POLICY.md` §8).

### Published detail requirements

- **Detail fetch** after navigation: **`MonoDetailDto`**-style payload (contract §5.1)—metadata + **sentence page window** references; avoid loading full learn payloads until Learn routes open.
- **Parser contract tests** on representative **`content` JSON** from backend snapshots.

### Learn mode requirements

- **Hub + drill-in:** **`LearnModuleDetailDto`** and related detail types **only** when user opens modules (`NIMON_API_QUERY_CONTRACT.md` §5.3–§5.5).
- **Language layers:** Explanations follow **`NIMON_LANGUAGE_SYSTEM.md`**—Source vs English fields; **invalidation** when Learn language setting changes may require reload of learner-facing summaries (cache policy §6).

### `readReady` / `learnReady` — flags vs derived logic

- **Derived (recommended for V1 consistency):**
  - **`readReady`:** `PublishedMono` exists and **`content.core`** parses to non-empty reader body OR structured pages (`publishReadOnly` succeeded).
  - **`learnReady`:** `StoryDraft.publishState === full_learn_published` **and** backend readiness checks for vocab/grammar/quiz/audio satisfied—**or** explicit booleans in `published_monos.content.metadata` if product needs faster queries without scanning draft tables.
- **Explicit flags** on Postgres (`published_monos`) optional later for indexing—avoid duplicating truth without migration discipline.

### Backend endpoint requirements

- **Existing:** `GET /v1/published-monos` (paginated owner list), publish endpoints under story-drafts module.
- **Still needed for full catalog UX:** **Public or scoped feed** `/mono/feed`-class route implementing **`NIMON_API_QUERY_CONTRACT.md`** §1–§2 (cursor + filters); **`GET /v1/published-monos/:id` or `/mono/:id`** detail for reader drill-in consistent with **`MonoDetailDto`**.
- **Errors:** Map **401/403** to re-auth UX per contract §8.

### Flutter screens to update

- **`lib/features/mono/**`** — swap mock feeds for repository-backed paged data; preserve performance budgets (patch counters, no global invalidate).
- **`lib/features/profile/**`** — Published tab already refreshes after publish; align detail-open path with unified detail API when added.
- **`lib/features/learn/**`** — ensure quiz/listening routes consume **server detail DTOs** where V1 promises real content; retire or isolate **`quiz_mock_bank`** for production flavor when ready.

### Tests needed

- **Golden:** `published_mono_detail_parser` with fixtures from real **`publishReadOnly`** snapshots.
- **Widget/integration:** Open Published row → reader renders pages; Learn button visibility vs `PublishedMonoAccess`.
- **Backend:** Publish snapshot schema regression tests (JSON shape).

### First implementation prompt

> Implement Nest **GET** published mono by id returning **`MonoDetailDto`**-compatible JSON (headline + core reader window per `NIMON_API_QUERY_CONTRACT.md`). Add Flutter `PublishedMonoRepository.getDetail(id)` and wire Profile → Mono reader to fetch detail instead of list-only data where needed. Define **`readReady` / `learnReady`** derivation in one Dart helper used by Mono + Learn entry. Add golden parser tests and one integration test: publish read-only → fetch detail → reader displays sentences. Do not embed learn module bodies in list endpoints.

---

## 10. Localization / ARB Plan

### ARB files

- **`lib/l10n/app_en.arb`** — template locale (`@@locale`: `en`).
- **`lib/l10n/app_ja.arb`** — secondary shipped locale (mirror keys).
- Future locales: add **`app_<locale>.arb`** with **same keys** as English (`NIMON_STRING_LOCALIZATION_PLAN.md` §9).

### App language setting

- **`MaterialApp`** / router shell receives **`locale`** from a Riverpod provider (pattern referenced in `NIMON_LANGUAGE_SYSTEM.md` and localization plan §6: **`appLocaleSettingProvider`**).
- Changing locale **must not** alter story field text—**chrome only**.

### SharedPreferences for selected app language

- **Persist** the user’s **App System Language** choice (`Locale` languageCode + countryCode if needed) in **`shared_preferences`** (or secure storage if combined with sensitive prefs—policy unchanged).
- On startup: **read** prefs → seed **`appLocaleSettingProvider`** before first frame where feasible.

### App Language vs Learn Language

| Concept | Role | Storage |
|---------|------|---------|
| **App System Language** | Buttons, tabs, errors, validation chrome | ARB + `Locale` |
| **Learn / Source Language** | Pedagogy explanations (`sourceMeaning`, etc.) | Entity fields + writer/learner settings—not ARB |

Rules and fallbacks: **`NIMON_LANGUAGE_SYSTEM.md`** §2, §6–§9 (never store Learn Language inside ARB).

### Migration from hardcoded strings

Follow **`NIMON_STRING_LOCALIZATION_PLAN.md`** phases **A–D**: inventory high-traffic screens (Settings → dialogs → Mono → Create → Profile), replace literals with **`AppLocalizations`**, add keys to **all** shipped ARBs in one PR, enable **`flutter gen-l10n`** in **`pubspec.yaml`** when product approves codegen (**interim:** optional `app_strings.dart` consts until ARB lands).

### File structure

```text
lib/l10n/
  app_en.arb
  app_ja.arb
  (future locales)
```

Generated output under **`.dart_tool`** / `flutter gen-l10n` default — import **`flutter_gen/gen_l10n/app_localizations.dart`** (exact path per Flutter version).

### First implementation prompt

> Enable **`flutter gen-l10n`** in `pubspec.yaml` (`generate: true`, `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`). Create **`app_en.arb`** and **`app_ja.arb`** with initial keys for **Login**, **Settings**, and **Mono** tab chrome only. Wire **`appLocaleSettingProvider`** (or equivalent) to **`MaterialApp.locale`** and persist locale in **`shared_preferences`**. Migrate **no** creator/learn pedagogy strings—per **`NIMON_LANGUAGE_SYSTEM.md`**. Run **`flutter gen-l10n`** and **`flutter analyze`**.

---

## 11. React / Bookmark / Share Plan

*(“React” = **content reactions**—likes/hearts—not the React.js framework.)*

### Backend tables (proposal)

Align with Postgres / Prisma—extend **`schema.prisma`** in a future migration:

| Table | Purpose |
|-------|---------|
| **`saved_monos`** | `userId`, `publishedMonoId`, `savedAt`, optional `collectionId` — unique `(userId, publishedMonoId)`. |
| **`collections`** (optional V1.1) | `id`, `ownerId`, `name`, `updatedAt`. |
| **`mono_reactions`** or **`published_mono_stats`** | Either **per-user reaction row** (`userId`, `publishedMonoId`, `kind`) for idempotent toggle, or **counter row** + separate user-reaction table for anti-abuse; avoid anonymous unlimited increments. |

Follow **`SavedMonoSummaryDto`** for list rows (`NIMON_API_QUERY_CONTRACT.md` §4.3).

### Endpoints (REST)

- **`POST /v1/saved-monos`** — body `{ publishedMonoId }` → idempotent **201/200**.
- **`DELETE /v1/saved-monos/:publishedMonoId`**.
- **`GET /v1/saved-monos`** — paginated summaries per contract §1.
- **`POST /v1/published-monos/:id/react`** — body `{ kind: 'like' }` toggle or **`PUT`** idempotent like—returns updated **`likesCount`**.
- **`GET /v1/published-monos/:id`** — include **`likesCount`** and **`viewerHasReacted`** when authenticated.

### Optimistic UI rules

Per **`NIMON_CACHE_AND_REFRESH_POLICY.md` §7:

- **Like:** bump **`likesCount`** and toggle **`viewerHasReacted`** locally; **rollback** on failure.
- **Bookmark:** toggle icon + queue **PATCH**; rollback on conflict **409**.
- **Do not** `invalidate` entire feed providers—**patch** the affected row (`NIMON_PERFORMANCE_BUDGETS.md` §3 anti-pattern 6).

### Counters

- **Denormalized `likesCount`** on **`published_monos`** or materialized view updated transactionally on reaction insert/delete—**or** accurate count via aggregate if volume low (product tradeoff).
- Client displays server value after successful sync; optimistic value is **best-effort** until ACK.

### Saved tab integration

- **Profile Saved tab** loads **`GET /v1/saved-monos`** with same pagination pattern as Published (`NIMON_API_QUERY_CONTRACT.md`).
- **Mono `onUnsavedMonoFeedItemId`** today removes local seeds—replace with **API delete** + **patch** Saved tab notifier (`NIMON_CACHE_AND_REFRESH_POLICY.md` §8 bookmark row).

### Share link strategy

- **Deep link:** `https://<app-domain>/m/<publishedMonoId>` (or custom scheme `nimon://mono/<id>`) resolved by app router **after** entity fetch validates visibility.
- **Client:** `share_plus` or platform share sheet with **canonical URL** + title; **no** secret tokens in link for public monos.
- **Open graph / preview:** backend **optional** metadata endpoint later—out of scope for minimal V1.

### First implementation prompt

> Add Prisma models **`SavedMono`** and reaction/likes schema; Nest modules **`saved-monos`** + **`reactions`** with idempotent REST endpoints per §11. Flutter: `SavedMonoRepository` with paginated lists; wire **`MonoScreen`** bookmark notifiers to **POST/DELETE** saved; **patch** feed row state on success without global `invalidate`. Add **`likesCount`** to **`MonoFeedSummaryDto`** mapping when backend sends it. Integration tests: save → appears in Profile Saved → unsave removes.

---

### Output summary (feature plan priorities)

| Track | Priority | Rationale |
|-------|----------|-----------|
| **SQLite / Drift migration** | **Lower / later** (`§6` **M8**) | Auth + remote sync semantics must stabilize first; prefs adequate until draft size/offline queue demands SQLite (`§8`). |
| **Published readiness** | **High** (`§6` **M4**) | Core user promise—published snapshot → reader → learn entry—depends on detail APIs + JSON contract (`§9`). |
| **ARB / localization** | **Medium** (`§6` **M7**) | Required for multi-market launches and hygiene; can trail core reader if single-locale beta (`§10`). |
| **React / bookmark / share** | **Medium** — after **M1 + M3/M5** | Depends on **identity** for per-user saved/react; feed summaries must expose counters (`§11`). |

---

## 12. Follow System Plan

### `user_follows` table (proposal)

| Column | Notes |
|--------|--------|
| **`followerId`** | FK → `users.id` (who follows). |
| **`followeeId`** | FK → `users.id` (who is followed). |
| **`createdAt`** | When follow started. |

Constraints: **Primary key** `(followerId, followeeId)`; **check** `followerId <> followeeId`; indexes on **`followeeId`** (followers list) and **`followerId`** (following list).

### Follow / unfollow endpoints

- **`POST /v1/users/:userId/follow`** — idempotent; auth user becomes follower; **409** if self-follow.
- **`DELETE /v1/users/:userId/follow`** — unfollow.
- **`GET /v1/users/:userId/followers`** — paginated (cursor per `NIMON_API_QUERY_CONTRACT.md`).
- **`GET /v1/users/:userId/following`** — same.

### Followers / following counts

- **Option A:** Denormalized **`followersCount`** / **`followingCount`** on **`user_profiles`** (or `users`) updated in transactions with follow edges—fast feed cards.
- **Option B:** **`COUNT(*)`** only on profile drill-in—simpler schema, slower at scale.

Expose **`followersCount`** / **`followingCount`** on **`MonoFeedSummaryDto`** writer fields when product requires (`NIMON_API_QUERY_CONTRACT.md` §4.1 extension).

### Follow tab in Mono feed

- Today **`MonoScreen`** implements **For You** vs **Following** with **mock** handles (`lib/features/mono/mono_screen.dart`). Replace **Following** page source with **`GET`** feed scoped by **`following`** + authenticated user—same cursor contract as catalog (`§9`, `NIMON_API_QUERY_CONTRACT.md`).
- Preserve **performance budgets**: patch rows, no global notifier invalidation (`NIMON_PERFORMANCE_BUDGETS.md`).

### Profile follow button

- **`public_profile_screen.dart`** / **`profile_connections_screen.dart`** (or equivalent): **Follow** / **Following** state from **`GET /v1/users/:id/relationship`** (viewer vs target: `none` \| `following` \| `blocked` later) or infer from counts + follow POST response.
- Optimistic toggle + rollback on failure (`NIMON_CACHE_AND_REFRESH_POLICY.md` §7).

### First implementation prompt

> Add Prisma model **`UserFollow`** mapped to **`user_follows`**. Nest **`follows`** module: POST/DELETE follow, GET followers/following with cursor pagination; optional **`relationship`** GET. Denormalize counts or document aggregate strategy. Flutter: replace **`_followingMockItems`** data source with authenticated **`FollowingFeedRepository`**; add follow button to public profile UI with optimistic state. Tests: service transactional integrity + one widget test for toggle.

---

## 13. Auth / Account Plan

### Current auth status

- **Flutter:** **`LoginScreen`** is UI-only—**LOGIN**, **Guest**, and **Sign up with Google** do not call APIs (`lib/features/auth/login_screen.dart`). **`devCurrentUserProvider`** supplies a fixed dev identity.
- **Nest:** **`AuthModule`** / **`UsersModule`** are **empty** placeholders; no guards on draft/publish routes in the baseline described in this plan.
- **Prisma:** **`User`** exists with optional **`email`**; comment: *“auth is not implemented yet”* (`nimon-backend/prisma/schema.prisma`).

### Login

- **Email + password:** `POST /v1/auth/login` → returns **access token** (and optional refresh) + **user** DTO; Flutter stores tokens per **SecureStorage** section below and sets session state in Riverpod.
- **Validation errors** map to App System Language strings (post-ARB) per `NIMON_LANGUAGE_SYSTEM.md` §4.

### Sign up

- **`POST /v1/auth/register`** — create `User`, hash password (e.g. Argon2/bcrypt), return session or require email verify if product adds verification later.
- **Guest path:** either **anonymous `User`** row or **device-scoped** id with upgrade flow—product decision before coding.

### Google sign-in

- **Flutter:** `google_sign_in` (or platform OAuth) → obtain **id_token** → **`POST /v1/auth/google`** with token; backend verifies JWT against Google JWKS, **upsert** user + OAuth linkage table (**optional** Prisma model **`oauth_accounts`**).
- **Placeholder button** on login screen currently **no-op**—wire only after backend route exists.

### Backend auth guard

- **NestJS:** JWT strategy + **`AuthGuard('jwt')`** on all **`/v1/story-drafts`**, **`/v1/published-monos`**, and future social endpoints; **`DEV_OWNER_ID`** env overrides **development-only** behind **`NODE_ENV`** / explicit flag.
- **Ownership:** `draft.ownerId` / `publishedMono.ownerId` must equal **`req.user.id`** (except admin roles later).

### SecureStorage

- Store **refresh token** and **access token** in **`flutter_secure_storage`** (or platform keystore); **never** in plain SharedPreferences.
- **Rotation:** refresh endpoint invalidates old refresh tokens if product requires.

### User profile bootstrap

- On first successful auth: **`GET /v1/me`** returns **`user` + `profile` + `settings` stubs**; create **default rows** in **`user_profiles` / `user_settings`** if missing.
- **Avatar, display name, handle** for Mono writer cards—align with public profile UI under **`lib/features/profile/**`.

### Replacing `DEV_OWNER_ID` / `NIMON_DEV_OWNER_ID`

- **Remove compile-time owner UUID** from release flavors; **`RemoteStoryDraftRepository`** sends **`Authorization: Bearer`** and derives **`ownerId`** from token server-side on **create/list** or trusts JWT **`sub`** only.
- **Development:** optional **`dart-define`** only for integration tests that impersonate a fixture user **after** auth exists—not primary mechanism.

### First implementation prompt

> Implement Nest **JWT auth**: register/login, password hashing, **`JwtAuthGuard`**, attach **`user`** to `Request`. Migrate **`story-drafts`** and **`published-monos`** controllers to require auth and scope **`ownerId`** to JWT subject; gate **`DEV_OWNER_ID`** list behavior to dev-only. Flutter: replace **`devCurrentUserProvider`** with **`sessionProvider`** reading SecureStorage; implement **`AuthRepository`** login/register; remove **`NIMON_DEV_OWNER_ID`** from release build yaml. Add **`GET /v1/me`**. Tests: guard rejects unauthenticated; draft create assigns owner from JWT.

---

## 14. Backend Table Roadmap

Mapped to **`nimon-backend/prisma/schema.prisma`** as of this document. Labels: **existing** | **missing** | **optional later**.

| Table / concept | Status | Notes |
|-----------------|--------|--------|
| **`users`** | **existing** | `User` model — minimal; optional `email`. |
| **`user_profiles`** | **missing** | Display name, handle, bio, avatar URL, **`followersCount`** / **`followingCount`** if denormalized. |
| **`user_settings`** | **missing** | App locale, learn/source language prefs, reader prefs—sync when backend ready (`NIMON_LANGUAGE_SYSTEM.md`). |
| **`story_drafts`** | **existing** | Full creator row + `hasUnpublishedCoreChanges`. |
| **`draft_sentences`** | **existing** | `DraftSentence`. |
| **`draft_vocab_entries` / `draft_grammar_entries` / `draft_quiz_entries` / `draft_audio`** | **existing** | Child tables JSON content. |
| **`published_monos`** | **existing** | `content` JSON; later **`likesCount`** optional column if denormalized. |
| **Reactions / likes** | **missing** | Per §11 — `mono_reactions` or equivalent + optional counter on `published_monos`. |
| **`saved_monos` / bookmarks** | **missing** | Per §11 — user ↔ published mono. |
| **`collections`** | **optional later** | Folders for Saved tab — V1 can ship flat saved list first. |
| **`collection_items`** | **optional later** | Join saved mono ↔ collection. |
| **`user_follows`** | **missing** | §12. |
| **`notifications`** | **optional later** | Push/in-app feed — not required for minimal V1 reader/creator loop. |
| **Auth / session tables** | **missing** | **`refresh_tokens`**, **`oauth_accounts`** (if Google), optional **`email_verification_tokens`**. |

---

## 15. API Endpoint Roadmap

REST only (`NIMON_API_QUERY_CONTRACT.md`). **Existing** (controllers today) vs **needed**.

### Auth / account

| Endpoint | Status |
|----------|--------|
| `POST /v1/auth/register` | **needed** |
| `POST /v1/auth/login` | **needed** |
| `POST /v1/auth/refresh` | **needed** (if refresh tokens) |
| `POST /v1/auth/google` | **needed** (Google path) |
| `GET /v1/me` | **needed** |

### Story drafts (creator)

| Endpoint | Status |
|----------|--------|
| `POST /v1/story-drafts` | **existing** |
| `GET /v1/story-drafts` | **existing** |
| `GET /v1/story-drafts/:draftId` | **existing** |
| `PUT /v1/story-drafts/:draftId` | **existing** (`If-Match`) |
| `DELETE /v1/story-drafts/:draftId` | **existing** |
| `POST /v1/story-drafts/:draftId/publish/read-only` | **existing** |
| `POST /v1/story-drafts/:draftId/publish/full-learn` | **existing** |

### Published monos

| Endpoint | Status |
|----------|--------|
| `GET /v1/published-monos` | **existing** (owner-scoped service today) |
| `GET /v1/published-monos/:id` | **existing** |

### Catalog / discovery (Mono)

| Endpoint | Status |
|----------|--------|
| `GET /v1/mono/feed` or `GET /v1/catalog/monos` | **needed** — public/scoped feed + cursor + filters (`§9`) |

### Social / engagement

| Endpoint | Status |
|----------|--------|
| `GET /v1/saved-monos` · `POST` · `DELETE` | **needed** (`§11`) |
| `POST /v1/published-monos/:id/react` (or `/likes`) | **needed** |
| `POST/DELETE /v1/users/:id/follow` · `GET` followers/following | **needed** (`§12`) |

### Health / ops

| Endpoint | Status |
|----------|--------|
| `GET /health` (or similar) | **existing** (`health` module) |

---

## 16. Test Strategy

### Flutter unit / provider tests

- **Repositories & DTOs:** `DraftListSummaryDto`, published mono parsers, pagination notifiers (`profile_*_pager`), **`RemoteStoryDraftRepository`** mapping—expand as APIs grow.
- **Riverpod:** notifier refresh behavior after publish (Published tab) stays covered; add tests for **session** / **auth** providers when implemented.

### Backend service tests

- **`story-drafts.service.spec.ts`** — extend for auth-scoped ownership, publish snapshots, edge cases on `updateDraft`.
- **New services:** auth, saved-monos, follows—**unit + integration** with Prisma test DB or mocks per team convention.

### Smoke tests

- **Manual / staging checklist** from `LOCAL_DB_FINAL_VERIFICATION_REPORT.md`: create draft → workspace → publish → Published tab → open reader → learn entry (remote draft mode + aligned API base URL).

### Strict remote tests

- Run integration tests with **`NIMON_USE_REMOTE_DRAFTS=true`** and **`NIMON_STRICT_REMOTE_DRAFTS=true`** (`NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md`) so silent local fallback does not hide API regressions.

### Release checklist tests

- **CI gate:** `flutter test` + `jest` (targeted `src/modules/**`) + `nest build` before tag.
- **Optional:** `flutter analyze` policy—triage **error** severity first; warnings infos backlog (`LOCAL_DB_FINAL_VERIFICATION_REPORT.md`).
- **Pre-release:** repeat **`prisma migrate status`** / **`migrate deploy`** on target environment.

---

## 17. AI / Cursor Safety Rules For Release Work

1. **One milestone per PR** — match **`§6`** milestones; e.g. do not ship auth + feed + SQLite in one changeset.
2. **Audit before refactor** — read **`NIMON_CONTENT_LIFECYCLE_AUDIT.md`** and affected module **before** restructuring `mono_screen.dart` / `profile_screen.dart` (mega-widget risk, `NIMON_PERFORMANCE_BUDGETS.md` §4).
3. **No global rewrites** — no repo-wide string replace, no mass rename without tests; **patch** Riverpod invalidation per **`NIMON_CACHE_AND_REFRESH_POLICY.md`** §8.
4. **Run `flutter test`** before merge on any Flutter touch.
5. **Run backend tests** (`jest` on changed modules) + **`nest build`** on Nest changes.
6. **Preserve docs** — update `README.md` / `DEV_RUN_COMMANDS.md` when flags or env vars change; do not delete established standards.
7. **Do not mix localization with backend work** — ARB/gen-l10n PRs stay Dart-only; Nest PRs stay TS-only unless coordinating a **documented** API error-code mapping.
8. **Do not mix auth with SQLite migration** — identity + guards first; Drift migration is a **separate** milestone (`§6` **M8** vs **M1**).

---

## 18. Final Recommendation

- **Current release readiness percentage:** **~55%** (same basis as **`§3`** — demo-strong creator/publish path; production gaps on identity, catalog, saved/social).
- **Biggest blocker:** **Production auth + authorization** — real sessions, JWT guards, SecureStorage, eliminating dev-owner UUID coupling (**§5**, **§7**, **§13**).
- **Recommended next milestone:** **M1 — Auth & account identity** (**§6**, **§7**) before catalog, SQLite, or ARB at scale.
- **SQLite migration before release?** **No** for first **public** V1 if **remote drafts + Postgres** remain authoritative and SharedPreferences suffice for local cache (**§6**, **§8**). Revisit **M8** when offline queue or draft size demands Drift.
- **GraphQL needed?** **No** — extend REST + cursor contract (**§5** output summary).
- **Top 5 files/modules to inspect next**

  1. **`nimon-backend/src/modules/auth/`** — implement real module (currently empty).
  2. **`nimon-backend/src/modules/story-drafts/`** — attach guards + ownership; confirm list/create use JWT `sub`.
  3. **`nimon-backend/src/modules/published-monos/`** — same; align `GET` list scope with authenticated user for production.
  4. **`lib/features/auth/`** — replace demo **`login_screen.dart`** / **`dev_current_user_provider.dart`** with session stack.
  5. **`lib/features/profile/`** — **`profile_screen.dart`**, **`profile_published_mono_pager.dart`**, **`remote_published_mono_repository.dart`** — wire to token-backed API and future **`/me`** profile bootstrap.

---

### Output summary

- **Current release readiness percentage:** **~55%**
- **Biggest blocker:** **Production auth / account identity** (JWT, guards, SecureStorage, remove dev-owner coupling).
- **Recommended next milestone:** **M1 — Auth & account identity**.
- **SQLite migration before release?** **No** for minimal public V1 if remote drafts + prefs remain acceptable; **yes/strongly consider** only when offline durability or draft scale forces it (**post-auth**, milestone **M8**).
- **GraphQL needed?** **No**.
- **Top 5 next modules:** **`nimon-backend` auth**, **`story-drafts`**, **`published-monos`**, **`lib/features/auth`**, **`lib/features/profile`** (session + published wiring).
