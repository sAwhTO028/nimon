# M3d Reader Detail Verification Plan

**Status:** Verification plan only (no code changes in this document).  
**Parent milestones:** [M3A_MONO_FEED_BACKEND_REPORT.md](M3A_MONO_FEED_BACKEND_REPORT.md), [M3B_MONO_FEED_FLUTTER_FOUNDATION_REPORT.md](M3B_MONO_FEED_FLUTTER_FOUNDATION_REPORT.md), [M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md](M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md).

**Objective:** Prove that **the same published story** presents **equivalent reader content** when opened from **Profile → Published** (owner-scoped API) vs **Mono Home → For You** (public catalog + hydration).

---

## 1. Current Reader Entry Points

### Profile → Published

- User is authenticated; list comes from **`GET /v1/published-monos`** (cursor paging via **`RemotePublishedMonoRepository`**).
- Opening a row: app loads **`GET /v1/published-monos/:id`** (owner-scoped detail), maps with **`monoFeedItemFromPublishedMonoDetail`** in [`published_mono_reader_mapper.dart`](../lib/features/profile/data/published_mono_reader_mapper.dart), then navigates to **`/mono-reader`** with **`MonoReaderMenuOrigin.profileUploaded`** (immersive reader shell).
- **Note:** Profile mapper prefixes feed item ids with **`profile-`** (`kProfilePublishedMonoIdPrefix`) so Profile-opened items remain distinguishable from catalog ids.

### Mono Home → For You (remote feed)

- When **`NIMON_USE_REMOTE_MONO_FEED=true`**, For You uses **`monoFeedPagerProvider`** → **`GET /v1/mono/feed`** summaries mapped via **`monoFeedItemFromMonoFeedSummary`** ([`mono_feed_item_mapper.dart`](../lib/features/mono/data/mono_feed_item_mapper.dart)).
- Full **`content`** is **not** in the feed list; **`needsRemoteDetailHydration`** is **true** until **`GET /v1/mono/:id`** succeeds ([`RemoteMonoFeedRepository.fetchMonoDetail`](../lib/features/mono/data/remote_mono_feed_repository.dart)).
- Hydrated **`PublishedMonoDetailDto`** merges into **`MonoFeedItem`** via **`monoFeedItemMergePublishedDetail`** (same parser helpers as Profile). Reader UI is the **in-shell** **`MonoScreen`** vertical **`PageView`** / **`_ReadingFeedPost`** — **not** the **`/mono-reader`** route unless product navigates there separately.

**Verification focus:** Compare **visible reading surface** (title, sentence bodies, Learn behavior), not necessarily identical route widgets — document both shells when recording smoke evidence.

---

## 2. Expected Reader Parity

For **the same underlying `published_monos.id`** (same **`content` JSON**), both entry paths should align after parsing:

| Aspect | Parity expectation |
|--------|---------------------|
| **Title** | Same effective title from detail DTO / merged item. |
| **Sentence text** | Same Japanese lines from **`content.core.sentences`** via **`buildMonoContentFromPublishedCore`** / **`plainBodyFromPublishedCore`** ([`published_mono_detail_parser.dart`](../lib/features/profile/data/published_mono_detail_parser.dart)). |
| **Furigana / ruby** | If parser path populates tokenized lines in future, both should match; **today** V1 parser often uses **plain** `MonoSentenceLine` from `japaneseText` — note actual vs wireframe. |
| **Source / English meaning** | Shown only if present in stored sentence `content` and reader widgets render them — record “N/A” if not in JSON. |
| **Level / category** | List + detail fields match backend row; Profile row may show extra labels from DTO — core JLPT/category should match. |
| **Publish kind** | **Read-only** vs **full learn** from **`displayPublishKind`** / **`PublishedMonoAccess`** — same gating rules for **Learn** affordance ([`published_mono_display_contract.dart`](../lib/features/profile/data/published_mono_display_contract.dart)). |
| **Learn button gating** | **`_openLearn`** in **`mono_screen.dart`** uses **`PublishedMonoAccess`**; hydrated Mono feed item must expose same **`publishedAccess`** as Profile-opened item when **`content`** matches. |

**Non-goals for this smoke:** pixel-perfect layout parity between **`/mono-reader`** and shell **`MonoScreen`** (different chrome); focus on **content equivalence** and **Learn gating**.

---

## 3. Manual Smoke Flow

**Environment**

1. Postgres running (`nimon-backend` per [DEV_RUN_COMMANDS.md](DEV_RUN_COMMANDS.md)).
2. Nest backend running (`npm run start:dev`).
3. Flutter with:

```bash
flutter run \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true \
  --dart-define=NIMON_API_BASE_URL=<reachable URL>
```

*Android emulator → host:* `http://10.0.2.2:3000`

**Steps**

| # | Action | Pass criteria |
|---|--------|----------------|
| 1 | Register / login | Session restored; Bearer calls succeed. |
| 2 | Create story basics + sentences | Saves under remote + strict without silent failure. |
| 3 | Publish **read-only** | **`published_monos`** row exists (Studio optional). |
| 4 | **Profile → Published** lists the mono | Row visible for owner. |
| 5 | **Mono Home → For You** (remote on) shows **same** story | Appears in catalog feed (may need refresh / scroll). |
| 6 | Open from **Profile** Published row | Reader shows expected title + sentence bodies + Learn behavior for RO. |
| 7 | Open from **Mono feed** (same mono; swipe to card or land on first page) | After hydration (or brief delay), **same** title + bodies + Learn behavior. |
| 8 | Side-by-side compare | Note any mismatch in text, gating, or missing hydration (SnackBar error). |

**Optional (full-learn path):** Repeat publish **full learn** and verify Learn / modal copy consistency across both entry points per product rules.

---

## 4. Automated Test Opportunities

| Area | Suggestion |
|------|------------|
| **Parser** | Golden / fixture tests for **`plainBodyFromPublishedCore`** + **`buildMonoContentFromPublishedCore`** with representative `content` JSON snapshots. |
| **Mapper** | Extend **`mono_feed_item_mapper_test.dart`**: edge cases (empty sentences, missing `core`, `read_only_v1` vs `full_learn_v1`). |
| **Summary + detail merge** | Already partially covered; add cases where **`description`**-only summary upgrades to full **`content`** after merge. |
| **Parity** | Pure-Dart test: same **`PublishedMonoDetailDto`** (mock JSON) → **`monoFeedItemFromPublishedMonoDetail`** vs **`monoFeedItemMergePublishedDetail(monoFeedItemFromMonoFeedSummary(summary), dto)`** — compare **`effectiveBodyText`**, **`publishedAccess`** flags (account for Profile id prefix in assertions). |
| **Widget / integration** | **Deferred** — full **`MonoScreen`** pump + HTTP mocks is heavy; prefer parser + mapper coverage first. |

---

## 5. Known Risks

| Risk | Why it matters |
|------|----------------|
| **Hydration timing** | Mono feed shows summary **`bodyText`** until **`GET /v1/mono/:id`** completes; user may see a flash or brief mismatch ([M3C report](M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md)). |
| **Detail fetch failure** | SnackBar only; reader may stay on teaser text — record as failure if persistent. |
| **JSON shape drift** | **`content.core.sentences`** vs legacy shapes — parser may return partial **`MonoContent`**. |
| **Read-only vs full-learn** | Wrong **`displayPublishKind`** → incorrect Learn modal / gating. |
| **Meaning lines** | If explanations live outside `japaneseText`, reader may omit unless UI reads extended fields. |
| **Profile id prefix** | **`profile-{uuid}`** vs raw **`uuid`** — comparisons must use underlying mono id or normalized comparison. |

---

## 6. Recommended M3d Implementation Scope (only if smoke fails)

Small, targeted fixes only:

| Issue type | Example fix |
|------------|-------------|
| Parser gaps | Add fixture + narrow parser handling for one failing payload shape. |
| Detail fetch UX | Clearer SnackBar / retry affordance on hydration failure. |
| Loading UX | Inline subtle loading hint while **`needsRemoteDetailHydration`** is true (optional). |
| Learn gating | Align **`publishedAccess`** from **`monoFeedItemMergePublishedDetail`** with **`publishedAccessFromDetail`** expectations. |

Avoid scope creep (no large **`mono_screen`** refactors in M3d).

---

## 7. Exact Cursor Prompt For M3d Smoke Report

Use after completing **§3** manual smoke:

```text
Create docs/M3D_READER_DETAIL_SMOKE_REPORT.md (verification only; no app code changes).

Summarize manual M3d reader parity verification:
- Environment: backend URL, Flutter dart-defines (remote drafts, strict, remote mono feed, API base URL).
- Same published mono opened from Profile Published vs Mono Home For You remote feed.
- For each path: title, body/sentences, Learn button behavior, read-only vs full-learn if tested.
- Note Profile /mono-reader vs in-shell MonoScreen if UX differs; judge content parity.
- List discrepancies, SnackBar/hydration issues, or parser gaps.
- Final verdict: Pass / Partial / Fail.
- Recommended next fix scope (small only).

Reference docs/M3D_READER_DETAIL_VERIFICATION_PLAN.md section 2 parity table.
```

---

## Output Summary

| Question | Answer |
|----------|--------|
| Profile entry understood? | **Yes** — owner list/detail → **`monoFeedItemFromPublishedMonoDetail`** → **`/mono-reader`**. |
| Mono feed entry understood? | **Yes** — public feed summary → **`GET /v1/mono/:id`** merge → in-shell **`MonoScreen`** reader. |
| Parity checklist ready? | **Yes** — §2 table + §3 manual steps. |
| Automated tests recommended? | **Yes** — parser fixtures, mapper parity, deferred widget tests (§4). |
| Next action | Run **§3** manual smoke; then **`M3D_READER_DETAIL_SMOKE_REPORT.md`** via §7 prompt; fix only if gaps found (§6). |
