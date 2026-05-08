# M4 Remaining Profile Listening Cover Audit

**Date:** 2026-05-03  
**Type:** Debug / audit only — **no code changes**, no migrations, no refactors in this task.

**Sources reviewed:** M4 closeout + M4b3a–d + creator audio URL + M3 reports (as listed in task); Flutter files under `lib/features/profile`, `lib/features/learn`, `lib/features/mono`, `lib/features/create`; Nest `story-drafts.service.ts`, `mono-feed`, `published-monos`, `prisma/schema.prisma`.

---

## 1. Issues Reported

1. **Profile → Published → Learn** shows learn content that looks like **old / local / mock** data instead of the published **`content.learn`** snapshot.
2. **Mono Home → Learn → Listening:** audio works, but **story sentence / transcript lines** do not appear.
3. **Story Basics:** cover **upload / select** appears to work in the creator, but the cover **does not display later** (reader / profile / mono).

---

## 2. Runtime Mode Assumptions

- **Catalog Learn path (M4b3a–d):** `learnPublishedSnapshotProvider` / `catalogPublishedMonoDetailProvider` are built around **`GET /v1/mono/:id`** (public catalog), where **`id` is the PublishedMono UUID** (same row as owner list).
- **`learnDemoMocksAllowed(contentId)`:** In **release** it is always **false**. In **debug**, it is **true** when `contentId` does **not** match the strict UUID regex (see `learn_catalog_content_gate.dart`).
- **Listening transcript:** M4b3d documents **no** transcript in published `StoryAudioDto`; UI uses route **`lines`** or empty + copy.
- **Cover on wire:** Published list/detail expose **`coverImageUrl`** derived from **`content.core.coverImageUrl`** (`published-mono-common.ts`), not a separate DB column on `PublishedMono`.

---

## 3. Profile Published Learn Data Audit

### A.1 From Profile Published, what route when user opens Learn?

- Profile opens the **Mono reader** first: `context.push('/mono-reader', extra: { items: [feed], ... })` (`profile_screen.dart` ~873–894).
- **Learn** is entered from **`MonoScreen`** (reader stack) when the user chooses Learn: `context.push('/learn/${item.id}', extra: { ... })` (`mono_screen.dart` ~2510–2520).

### A.2 Real published mono id vs prefixed id?

- For **backend-published** rows, Profile loads detail via **`GET /v1/published-monos/:id`** (`RemotePublishedMonoRepository.get`), then maps with **`monoFeedItemFromPublishedMonoDetail(d)`**.
- That mapper sets **`MonoFeedItem.id` to `'profile-' + d.id`** (`published_mono_reader_mapper.dart`, `kProfilePublishedMonoIdPrefix`).
- Learn routes therefore receive **`contentId == 'profile-<uuid>'`**, **not** the raw catalog UUID.

### A.3 Does `learnPublishedSnapshotProvider` call `GET /v1/mono/:id`?

**Yes.** `catalogPublishedMonoDetailProvider` calls `remoteMonoFeedRepositoryProvider.fetchMonoDetail(id)` → public **`GET /v1/mono/:id`** (`learn_published_snapshot_providers.dart`). The path parameter is whatever was passed as **`contentId`** on the Learn route (including the **`profile-`** prefix if present).

### A.4 If Profile uses owner `GET /v1/published-monos/:id`, is that seeded into the learn provider?

**No.** The owner fetch is used only to build the **`MonoFeedItem`** passed into the reader. **`learnPublishedSnapshotProvider` / `catalogPublishedMonoDetailProvider` do not read that response.** There is **no** “seed catalog cache from owner detail” step today.

### A.5 Provider cache / id mismatch?

- **Not a classic Riverpod key collision** between two UUIDs; the issue is a **single wrong key**: `profile-<uuid>` is **not** a valid public mono id for `GET /v1/mono/:id` (backend looks up by PublishedMono `id` only; `profile-` prefix will not match).
- **Debug:** `catalogMonoIdLooksLikeUuid('profile-<uuid>')` is **false** → **`learnDemoMocksAllowed` → true** → Learn screens may show **dev mock lists** (e.g. `VocabKanjiListScreen.mockItems`), which matches “old/local data”.
- **Release:** mocks are off; catalog fetch **errors** or returns unusable detail → UI may show **loading/error/empty** paths rather than published snapshot — still **not** published data.

### A.6 Are Learn screens still falling back to dev mocks for this id?

**In debug, yes** for `profile-<uuid>` because it fails the UUID gate (`learn_catalog_content_gate.dart`). **In release, no** — but the **catalog provider still uses the wrong id**, so published snapshot hydration from **`GET /v1/mono/:id`** cannot succeed without a separate fix.

### A.7 Is `publishKind` `full_learn_v1` visible on Profile-owned detail?

**Yes on the wire:** Owner detail returns full **`content`** (`published-monos.service.ts` / DTO). Backend full-learn publish sets **`content.publishKind`** to **`full_learn_v1`** (`story-drafts.service.ts` ~946–951). List rows also expose **`publishKind`** via `publishedMonoListItemFromRow`. The gap is **Flutter routing / provider id**, not absence of `publishKind` on Profile payloads.

---

## 4. Listening Transcript Audit

### B.1 Does `content.learn.audio.storyAudio` contain transcript lines?

**No (V1).** The learn snapshot is built from **`draft_audio`** row **`content`** only (`buildLearnSnapshotFromDraft` in `story-drafts.service.ts` ~95–107). Flutter **`StoryAudioDto`** / M4a wire do not define a timed transcript array inside **`storyAudio`** for published learn. M4b3d states transcript comes from **route `lines`** or empty.

### B.2 Does `published_monos.content.core.sentences` contain story sentences?

**Yes for read-only / full-learn publish path** that writes **`core.sentences`** (read-only publish merges **`core`** from draft sentences; see `story-drafts.service.ts` read-only block ~796–810 in prior milestones). Those are **reader / mono** story lines, **not** wired into **`ListeningPronunciationScreen`** today.

### B.3 Should Listening show transcript from `content.core.sentences` when no audio transcript exists?

**Not implemented.** Current Listening screen **does not** read `content.core` for transcript; it only uses **`LearnPublishedSnapshot.storyAudio`** + optional route **`lines`**.

### B.4 Does `ListeningPronunciationScreen` receive route `lines` from Mono / Learn hub?

**Learn hub** pushes listening with **`extra`: `storyTitle` + `explanationLanguage` only** — **no `lines`, no `audioUrl`** (`learn_hub_screen.dart` ~462–469). **Mono** Learn entry similarly passes **cover / title / meta** only (`mono_screen.dart` ~2512–1519). So **catalog UUID path** relies entirely on **published snapshot** for audio; **transcript stays empty** unless route adds `lines` elsewhere.

### B.5 Intentionally audio-only for M4b3d?

**Yes for transcript:** M4b3d documents **“no published transcript model”** and **honest empty message** when `lines` is empty. Audio-only playback when **`sourceUrl`** is valid **https** is the intended V1 behavior.

### B.6 Recommended V1 fix (transcript)?

- **Lower scope:** Derive **display-only** transcript lines from **`content.core.sentences`** (e.g. `japaneseText` per line) when `lines` is null and snapshot audio is present — **no** sync/timing; aligns with user expectation “sentences under listening.”
- **Larger scope:** Extend **`storyAudio`** (draft + publish) with a **transcript model** and backend snapshot — more work, schema/content contract change (out of scope for this audit).

---

## 5. Cover Image Upload / Display Audit

### C.1 Which UI handles cover?

- **`CreateStoryBasicsForm`** inside **`StoryCreatorBasicsScreen`** (`story_creator_basics_screen.dart` + `create_story_basics_form.dart`): gallery **`ImagePicker`**, optional **network URL** path, thumbnail preview via **`Image.file` / `Image.memory` / `Image.network`**.

### C.2 What is stored: path, bytes, asset, URL?

- **Picker:** sets **`_coverLocalPath`** (and on web **`_coverWebBytes`**) or clears **`_coverNetworkUrl`**.
- **Draft field `coverImageUrl`:** `_coverImageUrlForDraft()` returns **`http(s)` from local path** if path is URL, else **`null` for device file paths`**; otherwise uses **`_coverNetworkUrl`** (`create_story_basics_form.dart` ~301–309).

### C.3 Does `StoryDraftMapper.fromDomainRemoteSafe` strip cover?

**No.** `stripLocalAudioFields` affects **audio** only; **`coverImageUrl`** is carried on **`StoryDraftBasicsDto`** as-is (`story_draft_mapper.dart`).

### C.4 Does remote PUT send `coverImageUrl` or local path?

**PUT** sends whatever is on **`StoryDraftBasicsDto`** from **`fromDomainRemoteSafe`**. Local filesystem paths are **not** rewritten to URLs — if **`coverImageUrl` is null**, PUT sends **null** (`remote_story_draft_repository.dart` basics map).

### C.5 Does backend store `coverImageUrl` on `StoryDraft` / `PublishedMono`?

- **`StoryDraft.coverImageUrl`** column exists (`schema.prisma` ~100).
- **`PublishedMono`:** no top-level cover column; cover is inside **`content.core.coverImageUrl`** on publish (`story-drafts.service.ts` read-only path sets **`core.coverImageUrl: draft.coverImageUrl`**, etc.).

### C.6 Do `publishReadOnly` / `publishFullLearn` copy cover into `published_monos`?

**Read-only publish** updates **`PublishedMono`** **`content.core`** including **`coverImageUrl` from draft** (per service). **Full learn** updates **`content.learn`** and **`publishKind`**; it does **not** remove **`core`** — **`core`** remains from prior read-only publish unless overwritten elsewhere.

### C.7 Mono feed / Profile / reader — `coverImageUrl` vs `coverUrl`?

- **Mono feed list:** **`coverUrl`** extracted from **`content.core.coverImageUrl`** (`mono-feed.service.ts` `extractContentMeta`).
- **Profile list/detail Flutter DTO:** **`coverImageUrl`** from API (`published-mono-common` / mapper).
- **Learn hub cover:** route **`extra.coverImageUrl`** from Mono (`mono_screen.dart`); Profile reader **`MonoFeedItem.coverImageUrl`** comes from detail DTO.

### C.8 Same class as audio (no upload/CDN)?

**Yes.** Local file / blob cover **never becomes** a stable **`http(s)`** on the draft → **never** lands in **`content.core.coverImageUrl`** on publish. **Additional Flutter issue:** **`StoryCreatorBasicsScreen._handleAutosaveDraftFields`** passes **`coverImageUrl: null`** on autosave with an explicit comment that cover is **not** persisted as local path in V1 (`story_creator_basics_screen.dart` ~40–46), so **debounced saves clear** remote-bound cover unless the user only relies on **Continue** with a **network** URL.

---

## 6. Backend Payload Findings

| Topic | Finding |
|--------|---------|
| **Learn snapshot** | `buildLearnSnapshotFromDraft` writes **`vocabularyKanji` / `grammar` / `quiz` / `audio.storyAudio`** only; **no** sentence transcript inside **`learn`**. |
| **`core` sentences** | Present on **`content.core`** after read-only publish (ordered sentence map). |
| **Public mono detail** | `GET /v1/mono/:id` returns same **`content`** shape as owner detail mapper expects (`mono-feed.service.ts` `getPublicMonoById`). |
| **Profile list cover** | Derived from **`content.core.coverImageUrl`** in `publishedMonoListItemFromRow`. |

---

## 7. Flutter Provider / Route Findings

| Topic | Finding |
|--------|---------|
| **Learn data source** | **`catalogPublishedMonoDetailProvider(monoId)`** only — **owner detail is not wired**. |
| **Profile → Learn `contentId`** | **`profile-<uuid>`** breaks catalog fetch and triggers **debug mocks**. |
| **Mono Home → Learn `contentId`** | Raw **UUID** — matches catalog design. |
| **Listening `lines`** | Not passed from **LearnHubScreen** or **MonoScreen**; empty transcript is **expected** with current routes. |

---

## 8. Most Likely Root Causes

1. **Profile Published Learn:** **`monoFeedItemFromPublishedMonoDetail`** prefixes **`MonoFeedItem.id`** with **`profile-`**, but **Learn** assumes **catalog UUID** for **`GET /v1/mono/:id`**. Owner detail is **never** fed into **`learnPublishedSnapshotProvider`**. **Debug** exacerbates with **mock** learn lists.
2. **Listening transcript:** **By design** no transcript in **`content.learn.audio.storyAudio`**; **no** route **`lines`** from hub/mono; **no** fallback to **`content.core.sentences`** in **`ListeningPronunciationScreen`**.
3. **Cover image:** **Local** cover does not map to **`coverImageUrl`** on draft (`_coverImageUrlForDraft`); **autosave** passes **`coverImageUrl: null`**; publish copies **draft** URL into **`core`** — if always null, **readers show no cover**. Same **URL/CDN** class of problem as listening audio for non-HTTP assets.

---

## 9. Recommended Fix Order

| Priority | Item | Rationale |
|----------|------|-----------|
| **P0** | **Profile Learn id + provider parity** | Wrong id breaks all published learn hydration from Profile; debug shows misleading mocks. |
| **P1** | **Cover: persist http(s) URL + stop autosave nulling cover intent** (or upload pipeline) | Users expect picked image to “stick”; today local path cannot round-trip remotely. |
| **P1 / P2** | **Listening: optional transcript from `core.sentences`** (or product decision to keep audio-only copy) | UX gap vs expectation; backend already has sentences on **`core`**. |

---

## 10. Exact Cursor Prompt For Profile Learn Fix

> **Task:** Fix Profile → Published → Learn using **published snapshot data**, not mocks or stale catalog errors.  
> **Context:** `monoFeedItemFromPublishedMonoDetail` sets `MonoFeedItem.id` to `'profile-' + publishedMonoId` (`published_mono_reader_mapper.dart`). Learn uses `catalogPublishedMonoDetailProvider(contentId)` → `GET /v1/mono/:id` (`learn_published_snapshot_providers.dart`). Prefixed ids are invalid for catalog fetch; in debug, `learnDemoMocksAllowed` treats them as non-UUID and enables mocks (`learn_catalog_content_gate.dart`).  
> **Requirements:**  
> (1) For Learn routes, use the **raw PublishedMono UUID** (strip `kProfilePublishedMonoIdPrefix` when present, or stop prefixing Learn-related ids while keeping prefix only where needed for unsave callbacks).  
> (2) Optionally add **`ownerPublishedMonoDetailProvider`** (or invalidate/seed) that calls **`GET /v1/published-monos/:id`** and expose **`learnPublishedSnapshotFromPublishedMonoDetail`** for the same `monoId`, OR prefetch owner detail into a provider that **`learnPublishedSnapshotProvider`** can watch — **without** duplicating inconsistent shapes.  
> (3) Add tests: Learn opened after Profile published path uses **UUID** for catalog provider; snapshot non-null when backend returns `content.learn`.  
> **Constraints:** Do not change DB schema; keep `MonoReaderMenuOrigin` / unsave prefix behavior intact if still required.

---

## 11. Exact Cursor Prompt For Listening Transcript Fix

> **Task:** When published listening audio plays but users expect **story lines**, define V1 behavior explicitly.  
> **Context:** `ListeningPronunciationScreen` uses `lines ?? []` for transcript; `LearnHubScreen` / `MonoScreen` do not pass `lines` in `extra`. `content.learn.audio.storyAudio` has no transcript DTO (M4b3d). `content.core.sentences` exists on published mono JSON.  
> **Pick one:**  
> **A)** Map `content.core.sentences` → `ListeningTranscriptLine` list when `lines == null` and `shouldUsePublishedLearnSnapshot` is true; OR  
> **B)** Keep audio-only; improve copy (“Transcript not included in this publish”) and document.  
> **Requirements:** No schema migration; if using **core** sentences, read from **`catalogPublishedMonoDetailProvider`** / detail DTO already loaded; handle empty core; widget tests for UUID path.  
> **Files:** `listening_pronunciation_screen.dart`, optionally `listening_transcript_models.dart`, `learn_hub_screen.dart` only if passing `lines` is preferred over in-screen derivation.

---

## 12. Exact Cursor Prompt For Cover Image URL Fix

> **Task:** Make cover **display after publish** when creators pick a gallery image.  
> **Context:** `_coverImageUrlForDraft()` returns **null** for non-HTTP local paths (`create_story_basics_form.dart`). `StoryCreatorBasicsScreen._handleAutosaveDraftFields` passes **`coverImageUrl: null`** on debounced autosave (`story_creator_basics_screen.dart`). Backend stores **`StoryDraft.coverImageUrl`** and copies **`draft.coverImageUrl`** into **`PublishedMono.content.core.coverImageUrl`** on read-only publish.  
> **Requirements (choose minimal product path):**  
> (1) **URL-first:** Require **https** cover URL for publish parity (mirror listening audio policy), with clear UI if user only picked a file; **OR**  
> (2) **Upload:** Integrate signed upload → set **`coverImageUrl`** to returned **https** URL on draft before save/publish.  
> (3) Fix autosave so it does **not** wipe a pending network URL; if local-only, show blocking copy until URL exists.  
> **Constraints:** No Prisma migration unless product adds a new store; align with **`published-mono-common`** **`core.coverImageUrl`** extraction.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Profile Published Learn likely cause** | **`profile-` prefixed `MonoFeedItem.id`** passed into **`/learn/...`** while **`learnPublishedSnapshotProvider`** only fetches **`GET /v1/mono/:id`** with that string; owner **`GET /v1/published-monos/:id`** is **not** wired into learn providers. **Debug → mock fallback** makes it look like “old/local” data. |
| **Listening transcript likely cause** | **Expected V1 gap:** no transcript in **`learn` audio** DTO; **no `lines` in route `extra`** from Mono / Learn hub; **no UI fallback** to **`content.core.sentences`**. |
| **Cover image likely cause** | **Local path never becomes `coverImageUrl`** on draft; **autosave forces `coverImageUrl: null`**; publish copies **null** into **`content.core`** — **no http(s) URL** for feed / reader / `Image.network`. |
| **P0 fix recommendation** | **Profile Learn routing + provider** (strip prefix **or** owner-detail-backed snapshot provider). |
| **P1 fix recommendation** | **Cover:** https URL or upload pipeline + **autosave** not clearing cover intent; **Listening:** derive lines from **`core.sentences`** **or** ship honest copy only. |
| **Upload/CDN needed?** | **For parity with “pick from gallery” as-shipped:** **Yes** (or manual **https** URL). **For URL-only creators:** **No** new infra if they paste a hosted image URL and autosave is fixed. |
