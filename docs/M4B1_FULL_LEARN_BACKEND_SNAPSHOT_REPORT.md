# M4b1 Full Learn Backend Snapshot Report

**Report date:** 2026-05-03  
**Scope:** Backend only — `publishFullLearn` writes `published_monos.content.learn`; `publishReadOnly` merges existing JSON without wiping `learn`.

---

## Files Changed

| File | Change |
|------|--------|
| `nimon-backend/src/modules/story-drafts/story-drafts.service.ts` | Added `shallowJsonObjectCopy`, `buildLearnSnapshotFromDraft`; `publishFullLearn` merges `learn` snapshot; `publishReadOnly` loads existing mono `content` and shallow-merges before writing `core`. |
| `nimon-backend/src/modules/story-drafts/story-drafts.service.spec.ts` | Tests for learn snapshot shape, vocab ordering, null quiz row → `{}`, missing audio → `storyAudio: null`, `core` preservation, read-only merge preserves `learn`. |

---

## Root Cause

`publishFullLearn` only updated **`publishKind`**, **`sourceDraftId`**, and **`updatedAt`**. Learn modules existed on **`draft_*`** rows after remote sync (M4a) but were **never copied** into **`published_monos.content`**, so public Mono detail could not expose learn data.

Separately, **`publishReadOnly`** replaced **`content`** with a **new object**, which **dropped** any existing **`content.learn`** after a prior full-learn publish.

---

## Learn Snapshot Shape

Written under **`content.learn`**:

```json
{
  "schemaVersion": 1,
  "vocabularyKanji": { "entries": [ /* shallow copies of draft_vocab_entries.content */ ] },
  "grammar": { "entries": [ /* draft_grammar_entries */ ] },
  "quiz": { "entries": [ /* draft_quiz_entries */ ] },
  "audio": { "storyAudio": { /* draft_audio content */ } | null }
}
```

- **Order:** Same as **`mapFullDraft`** — sort each relation by **`order`** ascending.
- **Entries:** `null`/non-object **`content`** → **`{}`** (empty object).
- **`storyAudio`:** **`null`** if no row with **`kind === 'storyAudio'`**; otherwise shallow copy of that row’s **`content`**.

---

## publishFullLearn Changes

After successful draft reload, **`publishedMono.update`** sets:

- **`...prev`** (existing publish JSON)
- **`learn`**: new snapshot from **`buildLearnSnapshotFromDraft(reloaded)`**
- **`publishKind`**: **`full_learn_v1`**
- **`sourceDraftId`**, **`updatedAt`**

---

## publishReadOnly Merge Safety

Before **`publishedMono.update`**, the service **`findUnique`** loads **`content`**. The update payload is **`{ ...prevContent, sourceDraftId, publishKind: read_only_v1, updatedAt, core }`**, so **`learn`** and other unknown keys (e.g. **`legacyTopLevel`** in tests) are **preserved** unless explicitly overwritten.

---

## Tests Added

| Test | Assertion |
|------|-----------|
| publishFullLearn snapshot | `schemaVersion === 1`, vocab order **`first`** → **`second`**, grammar/quiz lengths, quiz **`null`** → **`{}`**, audio copied |
| No audio row | `learn.audio.storyAudio === null` |
| publishReadOnly merge | Prior **`learn`** and **`legacyTopLevel`** kept; **`core`** present; **`read_only_v1`** |

---

## Prisma Generate Result

```bash
node ./node_modules/prisma/build/index.js generate
```

**Result:** Success — Prisma Client generated (v7.7.0).

---

## Backend Test Result

```bash
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts
```

**Result:** **13 passed** (includes new publish tests).

---

## Backend Build Result

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** **Success** (exit code 0).

---

## Remaining Risks

- **Stale learn:** If the draft is edited after full learn, **`hasUnpublishedCoreChanges`** flags dirty; **`content.learn`** updates **only** on the **next** **`publishFullLearn`** (by design).
- **Large payloads:** Full quiz/vocab in **`content`** increases row size — monitor DB/API limits.
- **Local audio paths:** Snapshot may contain device-local URLs — clients must handle non-HTTPS URLs for listening.

---

## Recommended Next Step

**M4b2 (Flutter):** Parse **`content.learn`** from **`PublishedMono`** detail (`GET /v1/mono/:id` / owner published mono) and add **`LearnPublishedSnapshot`** models + tests per [M4B_FULL_LEARN_PUBLISH_SNAPSHOT_PLAN.md](M4B_FULL_LEARN_PUBLISH_SNAPSHOT_PLAN.md).
