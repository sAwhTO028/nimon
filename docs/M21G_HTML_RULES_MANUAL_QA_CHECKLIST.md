# M21G — HTML Rules Manual QA Checklist (Final Release Check)

Date created: 2026-06-02  
Scope: **Documentation only** (no code/test/rule changes)

## Purpose

This checklist is the **manual release verification** for the final “HTML generator rules as source-of-truth” rollout.

Reference:
- `docs/M21F_HTML_RULES_PARITY_FINAL_AUDIT.md`

## Test profile (use for all cases unless overridden)

- **Prompt mode**: `AI_mode` (unless Manual range case is explicitly tested)
- **Learning language**: JP (Japanese)
- **Level**: `N4/A2` (or `N4` if the UI only shows JLPT; must normalize to `N4/A2`)
- **Duration band key**: `5_7` (5–7 mins)
- **Preset**: default (AI slider default)

## 1) ReadOnly import QA (HTML rules)

**Goal**: Imported ReadOnly JSON obeys sentence + character min/max for AI JP N4/A2 5–7.

Use a ReadOnly import JSON generated for:
- `AI_mode`
- `Japanese` (JP)
- `N4/A2`
- `5_7`

Verify:
- **41 sentences** → import **blocked**
- **42 sentences with too few chars** (< 750 total JP chars after trimming + removing whitespace) → import **blocked**
- **42 sentences with 750–1100 chars** total → import **OK**

## 2) FullLearn import QA (HTML rules)

**Goal**: Imported FullLearn JSON obeys AI default selected counts, and missing audio is preview-only.

Use a FullLearn import JSON generated for:
- `AI_mode`
- `Japanese` (JP)
- `N4/A2`
- `5_7`
- default preset

Verify the **default preset counts** are enforced:
- **Vocabulary**: 16
- **Grammar**: 6
- **Quiz total**: 21
- **Vocabulary quiz**: 11
- **Grammar quiz**: 5
- **Sentence quiz**: 4

Audio behavior:
- **Missing audio** → import **OK**, but **preview-only / not publish-ready**

## 3) Storytelling QA (rendering correctness)

**Goal**: Reader/story surfaces display imported content correctly.

Verify:
- **Furigana appears** where expected.
- **Furigana position matches** the correct kanji/word.
- **Repeated kanji words** do **not** attach furigana to the wrong occurrence.
- **Meanings display correctly**:
  - Burmese meanings show correctly where expected.
  - English meanings show correctly where expected (note: this is meaning-display, not “English learning mode”).

## 4) Readiness QA (creator readiness / drawer)

**Goal**: Creator readiness matches HTML limits and responds to audio + quiz distribution.

Verify:
- **ReadOnly ready** when story meets HTML sentence + char limits.
- **FullLearn not ready without audio**.
- **FullLearn ready** after attaching **valid audio** and having correct counts.
- **Wrong quiz distribution** makes **FullLearn not ready** (even if total quiz count is correct).

## 5) Client publish preflight QA (Flutter)

**Goal**: Client preflight uses HTML limits and blocks/passes exactly as expected.

Verify:
- **Valid ReadOnly** passes preflight.
- **FullLearn without audio** blocks (module workflow gate).
- **FullLearn with vocab 15** (instead of 16) blocks.
- **FullLearn with correct counts + audio** passes.

## 6) Backend publish QA (server)

**Goal**: Backend publish validation matches Flutter preflight behavior and issue codes.

Verify:
- Backend **accepts the same valid payload** that Flutter preflight accepts.
- Backend rejects vocab mismatch with:
  - **`publish.htmlRules.vocabularyCountMismatch`**
- Backend rejects sentence/char mismatch with HTML issue codes, e.g.:
  - **`publish.htmlRules.storySentenceTooFew`**
  - **`publish.htmlRules.storySentenceTooMany`**
  - **`publish.htmlRules.storyCharsTooFew`**
  - **`publish.htmlRules.storyCharsTooMany`**

## 7) English QA (not enabled)

**Goal**: Confirm English learning mode is still blocked/not enabled.

Verify:
- **English learning import remains blocked**.
- **No English publish path** is enabled.

## 8) Result tracking table

Use this table to track execution and sign-off.

| Case ID | Scenario | Expected result | Actual result | Status (Pass/Fail/Blocked) | Notes | Date checked |
|---|---|---|---|---|---|---|
| RO-1 | ReadOnly import: AI JP N4/A2 5_7, 41 sentences | Block import |  |  |  |  |
| RO-2 | ReadOnly import: 42 sentences, total JP chars < 750 | Block import |  |  |  |  |
| RO-3 | ReadOnly import: 42 sentences, total JP chars 750–1100 | Import OK |  |  |  |  |
| FL-1 | FullLearn import: AI JP N4/A2 5_7, default counts, missing audio | Import OK, preview-only |  |  |  |  |
| ST-1 | Storytelling: furigana renders | Correct furigana appears |  |  |  |  |
| ST-2 | Storytelling: furigana alignment | Furigana attached to correct tokens |  |  |  |  |
| ST-3 | Storytelling: repeated kanji | No mis-attachment on repeats |  |  |  |  |
| ST-4 | Storytelling: meanings | Burmese/English meanings display correctly |  |  |  |  |
| RD-1 | Readiness: ReadOnly ready when story valid | ReadOnly ready=true |  |  |  |  |
| RD-2 | Readiness: FullLearn without audio | FullLearn ready=false |  |  |  |  |
| RD-3 | Readiness: FullLearn with valid audio + counts | FullLearn ready=true |  |  |  |  |
| RD-4 | Readiness: wrong quiz distribution | FullLearn ready=false |  |  |  |  |
| CP-1 | Client preflight: valid ReadOnly | Pass |  |  |  |  |
| CP-2 | Client preflight: FullLearn without audio | Block |  |  |  |  |
| CP-3 | Client preflight: FullLearn vocab 15/16 | Block |  |  |  |  |
| CP-4 | Client preflight: FullLearn correct + audio | Pass |  |  |  |  |
| BE-1 | Backend publish: accepts same valid payload | Accept |  |  |  |  |
| BE-2 | Backend publish: vocab mismatch issue code | Reject with publish.htmlRules.vocabularyCountMismatch |  |  |  |  |
| BE-3 | Backend publish: sentence/char mismatch codes | Reject with publish.htmlRules.story* codes |  |  |  |  |
| EN-1 | English import blocked | Block import |  |  |  |  |
| EN-2 | English publish path disabled | No path / blocked |  |  |  |  |

