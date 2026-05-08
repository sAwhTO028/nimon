# M3 Mono Feed Reader Closeout Report

**Report date:** 2026-05-03  
**Type:** Milestone closeout (documentation only — no app or test changes in this file).

This report consolidates **M3** public Mono feed + reader work, follow-on **P0** profile pagers, **P1** reader content, **remote sentence wire** sync, and **manual smoke** results provided by the team.

**Reference docs:** [M3A_MONO_FEED_BACKEND_REPORT.md](M3A_MONO_FEED_BACKEND_REPORT.md), [M3B_MONO_FEED_FLUTTER_FOUNDATION_REPORT.md](M3B_MONO_FEED_FLUTTER_FOUNDATION_REPORT.md), [M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md](M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md), [M3D_READER_DETAIL_SMOKE_REPORT.md](M3D_READER_DETAIL_SMOKE_REPORT.md), [P0_PROFILE_PAGER_PUBLISH_VISIBILITY_FIX_REPORT.md](P0_PROFILE_PAGER_PUBLISH_VISIBILITY_FIX_REPORT.md), [P1_FURIGANA_TRANSLATION_FIX_REPORT.md](P1_FURIGANA_TRANSLATION_FIX_REPORT.md), [REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md](REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md).

---

## Completed Milestones

| Area | What shipped |
|------|----------------|
| **M3a — Backend** | Public `GET /v1/mono/feed` (cursor paged) and `GET /v1/mono/:monoId` (detail); owner routes unchanged. |
| **M3b — Flutter data** | `RemoteMonoFeedRepository`, `monoFeedPagerProvider`, DTOs, tests; `NIMON_USE_REMOTE_MONO_FEED` flag. |
| **M3c — Mono Home** | For You wired to remote feed + detail hydration when flag on; mock path preserved when off. |
| **P0 — Profile** | Workspace / Published pager epoch loading-flag fixes; Profile scheduling tweaks; publish visibility audit path. |
| **P1 — Reader content** | Published-core parser: `furiganaSpans` → tokens, `meanings` → explanations; Mono translations toggle + structured scroll. |
| **Remote sentence wire** | `RemoteStoryDraftRepository` sentence JSON round-trip for `furiganaSpans` and `meanings` (PUT/GET parity with local storage). |

---

## Manual Verification Result

**Recorded manual outcome (post-fix):**

| Check | Result |
|-------|--------|
| Remote sentence save — furigana / source meaning / English meaning | **Works** |
| `draft_sentences.content` after remote save | Includes **`furiganaSpans`** and **`meanings`** |
| Published snapshot | Sentence **content** carried correctly |
| Mono Home remote feed | **Shows** published story |
| Reader | **Shows furigana** |
| Settings → **Show Mono translations** ON | **Shows** translations |
| Toggle OFF | **Hides** translations |
| Workspace empty loading | **Fixed** (no endless spinner in verified scenario) |
| Profile → Published | **Shows** newly published content |

---

## Feed Behavior

- **Mono Home → For You** (with `NIMON_USE_REMOTE_MONO_FEED=true`): loads **`GET /v1/mono/feed`**, paginates, filters by level where wired; **hydrates** rows via **`GET /v1/mono/:id`** per [M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md](M3C_MONO_SCREEN_REMOTE_FEED_REPORT.md).
- **Following** tab remains mock / unchanged per M3c scope.
- Feed summary stays slim (no full `content` blob in list API — per M3a).

---

## Reader Detail Behavior

- Detail path uses public **`/v1/mono/:id`** for catalog items; merged into **`MonoFeedItem`** with published core parsing (M3c + mappers).
- **Profile → Published** owner path remains on **`/v1/published-monos`** (JWT) — both land on compatible **`PublishedMonoDetailDto`** / parser shape when content is present.

---

## Furigana / Translation Result

- **Creator → server:** Remote wire fix ensures **PUT** sentence JSON includes **`furiganaSpans`** and **`meanings`**, matching local storage and P1 reader expectations ([REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md](REMOTE_SENTENCE_TRANSLATION_FURIGANA_SYNC_FIX_REPORT.md)).
- **Reader:** P1 parser builds **`MonoRubyToken`** paths from **`furiganaSpans`**; meanings mapped into **`MonoExplanationLine`**; Mono Screen respects **`monoReaderTranslationEnabledProvider`** ([P1_FURIGANA_TRANSLATION_FIX_REPORT.md](P1_FURIGANA_TRANSLATION_FIX_REPORT.md)).

---

## Profile / Workspace Result

- **Pager races** addressed so initial load / refresh do not leave **`isInitialLoading`** stuck ([P0_PROFILE_PAGER_PUBLISH_VISIBILITY_FIX_REPORT.md](P0_PROFILE_PAGER_PUBLISH_VISIBILITY_FIX_REPORT.md)).
- **Manual:** Published tab lists new content after publish; Workspace empty-loading issue reported resolved in verification.

---

## Tests Summary

Automated coverage is documented in the per-topic reports (M3a backend specs; M3b/M3c Flutter tests; P0/P1/remote wire tests). **This closeout does not re-run or modify tests.** Representative scopes:

- Mono feed: DTO, repository, pager, item mapper tests (M3b/M3c reports).
- Profile pagers: regression tests for superseded load vs refresh (P0 report).
- Sentence wire: round-trip tests for spans/meanings (remote sync report).

---

## Remaining Risks

| Risk | Notes |
|------|--------|
| **Non-sentence draft layers on remote** | Vocab/grammar/quiz JSON in `RemoteStoryDraftRepository` may still use partial stubs — separate from sentence fix. |
| **Feed performance** | M3a still reads `content` from DB for teaser extraction — monitor at scale. |
| **`byLanguage` meanings** | P1 reader focuses on `en`/`my`; extended maps are optional / deferred. |
| **`M3D_READER_DETAIL_SMOKE_REPORT`** | Template smoke doc may still show **Pending** cells unless updated — superseded for parity **title row** by this closeout’s manual result for the exercised build. |
| **Env / defines** | Remote feed + drafts require correct **`dart-define`** and reachable API (see M3d smoke env table). |

---

## Final Verdict

For the **scoped M3 Mono catalog + remote Mono Home + reader hydration**, plus **P0/P1/remote sentence** fixes described above: **the milestone is closed** relative to the **manual verification table** in this document and the referenced implementation reports. Outstanding items are **non-blocking risks** (above) or **follow-up milestones** (below), not reopeners for core M3 delivery.

---

## Recommended Next Milestone

1. **M4 / integration hardening (suggested):** Align remaining remote draft wire serializers (vocab/grammar/quiz) with `StoryDraftMapper`, or centralize one serializer — reduces drift after sentence fix.
2. **Performance / query:** Scalar teaser columns or slimmer feed projection per M3a notes if catalog grows.
3. **Product QA:** Full formal pass updating [M3D_READER_DETAIL_SMOKE_REPORT.md](M3D_READER_DETAIL_SMOKE_REPORT.md) parity table with UUID + screenshots if release requires audit trail.
4. **Search / Following:** M3a deferred full-text search; Following tab real feed — product-dependent.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **M3 closed?** | **Yes**, for public feed + Flutter wiring + reader hydration + verified creator→publish→reader chain per this report. |
| **Manual smoke passed?** | **Yes** — per **Manual Verification Result** above. |
| **Furigana / translation verified?** | **Yes** — save, DB snapshot, reader display, Settings toggle ON/OFF. |
| **Profile / Workspace verified?** | **Yes** — Published shows new content; Workspace empty loading fixed in verification. |
| **Remaining risks** | Partial remote stubs for non-sentence layers; feed `content` read for teasers; optional docsparity with M3d smoke template; env defines. |
| **Next milestone** | Remote draft serializer alignment for non-sentence layers; perf/teasers; formal M3d smoke doc update; Following/search per roadmap. |
