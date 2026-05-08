# Listening Transcript Fallback Fix Report

**Report date:** 2026-05-05  
**Scope:** Flutter only — catalog Learn → Listening / Pronunciation shows published **core story sentences** (with furigana and optional translations) when no explicit transcript lines are provided. Backend unchanged.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/listening_transcript_models.dart` | `ListeningTranscriptLine` gains optional `rubyTokens` (`MonoRubyToken`) and `publishedExplanation` (`MonoExplanationLine`) for catalog core parsing. |
| `lib/features/learn/listening_transcript_from_published.dart` | **New.** Builds transcript lines via `buildMonoContentFromPublishedCore` → `ListeningTranscriptLine` (single code path with Mono reader). |
| `lib/features/learn/listening_pronunciation_screen.dart` | Merges route `lines` (if non-empty) with **fallback** from `detail.content` core; `ListeningTranscriptSentenceBlock` uses `NimonRubyText` + `monoLineExplanationDisplay`; visibility uses **`monoReaderTranslationEnabledProvider`**. |
| `test/features/learn/listening_transcript_from_published_test.dart` | **New.** Unit tests for fallback mapping. |
| `test/features/learn/listening_transcript_sentence_block_test.dart` | **New.** Widget tests: translation on/off, `NimonRubyText` when tokens present. |
| `test/features/learn/listening_hydration_widget_test.dart` | Catalog fixture includes `content.core.sentences`; asserts no empty-transcript copy and one `NimonRubyText`. |

## Root Cause

Published **story audio** in the learn snapshot does not carry timed transcript lines (see `docs/M4B3D_LISTENING_HYDRATION_REPORT.md`). The screen only used `lines` from the route, which is almost always **null/empty** for catalog flows, so the UI showed *“No transcript is published for this story yet.”* even when **published `content.core.sentences`** was available with full Japanese, furigana, and meanings.

## New Transcript Data Flow

1. Load `catalogPublishedMonoDetailProvider` + `learnPublishedSnapshotProvider` (unchanged).
2. If **HTTP(S) story audio** exists, keep **`_ListeningPlaybackView`** and `just_audio` behavior (unchanged).
3. **Transcript list resolution:**
   - If route **`lines` is non-null and non-empty** → use as the explicit transcript (future timed/aligned data or deep links).
   - Else → **`listeningTranscriptLinesFromPublishedCore(detail.content)`**, which delegates to **`buildMonoContentFromPublishedCore`** and maps each `MonoSentenceLine` to a `ListeningTranscriptLine`.
4. **Empty message** *“No transcript is published for this story yet.”* is shown only when the resolved list is **empty** (no explicit transcript **and** no usable core sentences).

## Furigana / Translation Behavior

- **Furigana:** When `rubyTokens` is non-empty, Japanese is rendered with **`NimonRubyText`** and **`resolveNimonFuriganaLineStyle`** (`NimonFuriganaPreviewContext.reading`), matching Mono reader styling. When tokens are empty, plain **`Text`** plus legacy optional **`reading`** (demo / simple transcript lines).
- **Translations:** Controlled by **`monoReaderTranslationEnabledProvider`** (Settings → **Show Mono translations**), aligned with Mono reader / P1 behavior.
  - If `publishedExplanation` is set → **`monoLineExplanationDisplay`** (source primary, English secondary when both differ).
  - Else → **`pickSupportText`** + route **`meaningEn` / `meaningMy`** (demo / legacy transcript lines).

## Tests Added

| File | Notes |
|------|--------|
| `test/features/learn/listening_transcript_from_published_test.dart` | Empty content; sentences with spans/meanings; plain sentence without spans. |
| `test/features/learn/listening_transcript_sentence_block_test.dart` | Translation hidden when off; primary explanation when on; `NimonRubyText` when tokens present (widget finder — `find.text` does not see custom ruby paint). |
| `test/features/learn/listening_hydration_widget_test.dart` | Extended HTTPS catalog fixture with `core.sentences`; empty-transcript copy absent; `NimonRubyText` present. |

## Flutter Analyze Result

```bash
flutter analyze lib/features/learn/listening_transcript_from_published.dart \
  lib/features/learn/listening_transcript_models.dart \
  lib/features/learn/listening_pronunciation_screen.dart \
  test/features/learn/listening_transcript_from_published_test.dart \
  test/features/learn/listening_transcript_sentence_block_test.dart \
  test/features/learn/listening_hydration_widget_test.dart
```

**Result:** No issues found.

*(Including `lib/features/profile/data/published_mono_detail_parser.dart` in the same analyze pass surfaces a pre-existing **info** lint: `depend_on_referenced_packages` for `characters` — unchanged by this task.)*

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/learn` | **38** passed |
| `flutter test` (full suite) | **231** passed |

## Remaining Risks

- **Sentence order / count** for listening is **story order** from published core, not time-aligned to audio (same as V1 scope in M4b3d).
- **Explicit empty transcript:** Passing `lines: []` still falls back to core (treated as “no override”). If product ever needs “force empty,” add a dedicated flag.
- **Ruby widget tests** avoid `find.text` for CJK because **`NimonRubyText`** paints base text in a **custom render object**, not `Text`.

## Recommended Next Step

Optional product pass: add Settings copy clarifying that **Show Mono translations** applies to Mono reader **and** Learn Listening; or add a dedicated Listening toggle only if UX research shows confusion.

## Output Summary

| Question | Answer |
|----------|--------|
| Listening shows story sentences for published catalog content? | **Yes** — fallback from `content.core.sentences` when no explicit transcript list. |
| Furigana shown? | **Yes** — via `furiganaSpans` → `MonoRubyToken` → `NimonRubyText`. |
| Translation toggle respected? | **Yes** — **`monoReaderTranslationEnabledProvider`** (same as Mono reader). |
| Audio unchanged? | **Yes** — same `publishedStoryAudioHttpUrl` + `_ListeningPlaybackView` / `just_audio`. |
| `flutter test test/features/learn` passed? | **Yes** (38 tests). |
| Full `flutter test` passed? | **Yes** (231 tests). |
