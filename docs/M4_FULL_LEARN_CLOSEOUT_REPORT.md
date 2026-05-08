# M4 Full Learn Closeout Report

**Report date:** 2026-05-03  
**Type:** Milestone closeout (documentation only — no app, migration, or test changes in this file).

This report consolidates **M4** remote learn-layer wire parity, **full-learn** publish snapshot on the backend, **Flutter** parse + catalog **Learn** hydration, and points to **manual smoke** still expected from the team. **References:** [M4A_LEARN_LAYER_WIRE_FIX_REPORT.md](M4A_LEARN_LAYER_WIRE_FIX_REPORT.md), [M4B1_FULL_LEARN_BACKEND_SNAPSHOT_REPORT.md](M4B1_FULL_LEARN_BACKEND_SNAPSHOT_REPORT.md), [M4B2_FLUTTER_LEARN_SNAPSHOT_PARSER_REPORT.md](M4B2_FLUTTER_LEARN_SNAPSHOT_PARSER_REPORT.md), [M4B3A_LEARN_SNAPSHOT_PROVIDER_MAPPERS_REPORT.md](M4B3A_LEARN_SNAPSHOT_PROVIDER_MAPPERS_REPORT.md), [M4B3B_VOCAB_GRAMMAR_HYDRATION_REPORT.md](M4B3B_VOCAB_GRAMMAR_HYDRATION_REPORT.md), [M4B3C_QUIZ_HYDRATION_REPORT.md](M4B3C_QUIZ_HYDRATION_REPORT.md), [M4B3D_LISTENING_HYDRATION_REPORT.md](M4B3D_LISTENING_HYDRATION_REPORT.md), [M3_MONO_FEED_READER_CLOSEOUT_REPORT.md](M3_MONO_FEED_READER_CLOSEOUT_REPORT.md).

---

## Completed Milestones

| Milestone | What shipped |
|-----------|----------------|
| **M4a — Learn layer wire** | `remote_story_draft_learn_layers_wire.dart` + `RemoteStoryDraftRepository` round-trip for vocab, grammar, quiz, and story audio; tolerant decode; tests. |
| **M4b1 — Backend snapshot** | `publishFullLearn` writes `content.learn` from draft learn layers; `publishReadOnly` shallow-merges so existing `learn` is not wiped; backend tests. |
| **M4b2 — Flutter parser** | `LearnPublishedSnapshot`, `learnPublishedSnapshotFromContent` / `FromPublishedMonoDetail`, reuses M4a wire decoders; parser tests. |
| **M4b3a — Provider + mappers** | `catalogPublishedMonoDetailProvider`, `learnPublishedSnapshotProvider`, DTO→UI mappers + `shouldUsePublishedLearnSnapshot`; provider/mapper tests. |
| **M4b3b — Vocab + Grammar** | `VocabKanjiListScreen`, `GrammarPatternListScreen`, `GrammarPatternDetailScreen` hydrated; `learn_catalog_content_gate.dart`; widget tests. |
| **M4b3c — Quiz** | `QuizSetupScreen` / `QuizPlayScreen` + `QuizSessionStartArgs.publishedQuizPool`; no `QuizMockBank` for catalog UUIDs; widget + session picker tests. |
| **M4b3d — Listening** | `ListeningPronunciationScreen` from `storyAudio` + HTTP(S) URL policy; `publishedStoryAudioHttpUrl`; listening widget + URL unit tests. |

---

## Full Learn Data Flow

1. **Creator / draft:** Learn layers edited locally and synced remotely with **M4a** wire shapes (`vocabularyKanji`, `grammar`, `quiz`, `audio.storyAudio`) aligned with draft storage JSON.
2. **Publish full learn (backend):** **M4b1** merges a **learn** snapshot into `published_monos.content` (`schemaVersion: 1`, ordered entries, `storyAudio` or null).
3. **Public read:** **M3** catalog detail (`GET /v1/mono/:id`) returns `content` including `learn` when present.
4. **Flutter parse:** **M4b2** maps `content.learn` → **`LearnPublishedSnapshot`** (or null when missing / unsupported schema).
5. **Learn routes:** **M4b3a** exposes snapshot from cached catalog detail; **M4b3b–d** map rows into existing Learn UI with **`publishKind`** + **`shouldUsePublishedLearnSnapshot`** gating (`full_learn_v1` / `full_learn` + non-empty learn data).

---

## Remote Draft Wire Result

Per **M4a**: Silent data loss on learn layers for remote PUT/GET is addressed. Vocab (`glosses`, examples, provenance, etc.), grammar (examples, mistakes, related note, etc.), quiz (options, explanations, `correctIndex` tolerance), and audio (including tolerant `localPath` aliases on decode) round-trip through the repository using shared wire helpers. Root cause was the same class of bug as pre-M3 sentences: null/empty emit and discard on read.

---

## Published Snapshot Result

Per **M4b1**: Full-learn publish now persists **`content.learn`** so readers can consume learn modules. Read-only republish preserves prior **`learn`** via shallow merge. Snapshot structure matches what **M4b2** parses (`schemaVersion`, `vocabularyKanji.entries`, `grammar.entries`, `quiz.entries`, `audio.storyAudio`).

---

## Learn Screen Hydration Result

| Screen | Catalog behavior (summary) |
|--------|----------------------------|
| **Vocabulary** | `learnPublishedSnapshotProvider` + `vocabKanjiItemFromPublishedEntry`; read-only / empty → honest copy; mocks only `learnDemoMocksAllowed`. |
| **Grammar list + detail** | `grammarPatternFromPublishedEntry`; no silent mock on UUID when `pattern` missing. |
| **Quiz setup + play** | Mapped pool in `QuizSessionStartArgs`; `QuizMockBank` only demo gate; UUID without pool → no fake deck. |
| **Listening** | `storyAudio` via `publishedStoryAudioHttpUrl` (http/https only); local-only → unavailable; transcript only from route `lines` or empty message; sample data only demo gate. |

Shared: **`catalogPublishedMonoDetailProvider`** for **`publishKind`**, **`learnPublishedSnapshotProvider`** for snapshot, loading/error/retry patterns on catalog ids.

---

## Manual Smoke Checklist

Use a real backend + app build; **full-learn** path end-to-end.

1. **Create** a story with **sentences** (core body).
2. **Add** vocab entries (creator learn layer).
3. **Add** grammar entries.
4. **Add** quiz entries.
5. **Add** story audio with **HTTP(S) `sourceUrl`** when the environment supports a reachable URL (optional if testing “unavailable” copy only).
6. **Save** remote draft (verify learn layers persist remotely per M4a).
7. **Inspect** `draft_*` learn-related tables or API payloads **if needed** for debugging.
8. **Publish read-only** first (optional ordering check).
9. **Publish full learn** (`publishKind` → full learn).
10. **Inspect** `published_monos.content.learn` (DB or admin) — expect **M4b1** shape with populated sections.
11. **Open Mono Home** feed (remote flag on per M3); open the published story / **Learn hub** (`/learn/:id`).
12. **Verify Vocabulary** shows **real** published rows (not dev mocks for UUID).
13. **Verify Grammar** list + detail from snapshot.
14. **Verify Quiz** setup → play uses **published** questions (not `QuizMockBank`).
15. **Verify Listening** — **real** HTTPS audio plays **or** honest **unavailable** / **no transcript** states (no sample MP3 / mock lines for UUID).
16. **Verify read-only** story (or mono without full learn): **does not** show fake learn modules — locked / empty messaging per screen.

Record pass/fail and any URL/CORS/audio issues in issue tracker.

---

## Tests Summary

Automated coverage is spread across:

- **M4a:** `remote_story_draft_learn_layers_wire_test.dart`
- **M4b2:** `published_mono_learn_snapshot_parser_test.dart` (under `test/features/profile/`)
- **M4b3a:** `learn_published_snapshot_mappers_test.dart`, `learn_published_snapshot_providers_test.dart`
- **M4b3b–d:** `vocab_grammar_hydration_widget_test.dart`, `quiz_hydration_widget_test.dart`, `quiz_session_test.dart`, `listening_hydration_widget_test.dart`, `listening_story_audio_url_test.dart`
- **M4b1:** backend `story-drafts.service.spec.ts` (Node)

Per **M4b3d** report, `flutter test test/features/learn` and full `flutter test` were green after listening hydration; **re-run** after any future change.

---

## Remaining Risks

- **Catalog-only provider:** `catalogPublishedMonoDetailProvider` targets public mono fetch; **owner / profile** `GET /v1/published-monos/:id` Learn entry may need the same parse path or a parallel family if users open Learn from Profile without hitting catalog detail first (**M4b3a** note).
- **Invalidation:** Pull-to-refresh on mono detail should **invalidate** `catalogPublishedMonoDetailProvider(monoId)` so Learn sees updated publish (**M4b3a** note).
- **Quiz:** Deep link to play without `QuizSessionStartArgs`; retry semantics tied to detail invalidation only (**M4b3c** notes).
- **Listening:** Route `extra.audioUrl` not merged when published `sourceUrl` missing; **just_audio** failures (403, TLS) show generic load error; **no timed transcript** in V1 DTO (**M4b3d** notes).
- **Gating edge cases:** Empty learn sections vs `hasAnyLearnData` / per-module empty copy (documented on quiz / listening reports).
- **Manual smoke** not recorded in this doc — **P0** for release confidence.

---

## Final Verdict

**M4 (full learn vertical) is implementation-complete** through **M4b3d**: draft wire → publish snapshot → parse → catalog Learn UI hydration with **read-only vs full-learn** honesty and **demo-only** mocks. **M4 is not “closed” for product/release** until **manual smoke** (checklist above) is executed and signed off on a staging/prod-like environment.

---

## Recommended Next Milestone

1. **M4b3e (optional polish):** Learn hub empty-state hints, coordinated **pull-to-refresh** invalidation, owner-path snapshot parity if Learn is opened from Profile-only flows.
2. **Post-M4 product:** Transcript model / sync listening, quiz analytics, or next roadmap epic — pick based on backlog priority after smoke sign-off.

---

## Output Summary (quick answers)

| Question | Answer |
|----------|--------|
| **M4 closed?** | **Code milestone closed** through M4b3d; **release “closed”** pending manual smoke sign-off. |
| **Full learn publish snapshot ready?** | **Yes** (M4b1 + M4b2); backend writes `content.learn`; Flutter parses into `LearnPublishedSnapshot`. |
| **Vocab / grammar / quiz / listening hydrated?** | **Yes** for catalog Learn routes (M4b3b–d) behind `shouldUsePublishedLearnSnapshot`. |
| **Mocks avoided for catalog UUIDs?** | **Yes** in release; dev-only `learnDemoMocksAllowed` for non-UUID / `mono` demos. |
| **Tests passed?** | **Automated tests** were green per sub-reports through M4b3d; **re-verify** after any new commits (this doc does not re-run CI). |
| **Remaining risks** | Profile/catalog provider split, invalidation, listening URL/transcript limits, manual smoke — see **Remaining Risks**. |
| **Next milestone recommendation** | **M4b3e polish + manual smoke sign-off**, then **owner-path learn** or next product epic. |
