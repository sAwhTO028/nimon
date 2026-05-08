# P1 Furigana Translation Fix Report

## Files Changed

| File | Purpose |
|------|---------|
| `lib/features/profile/data/published_mono_detail_parser.dart` | Parse `furiganaSpans` → `MonoRubyToken` list; parse `meanings` / legacy keys → `MonoExplanationLine`. |
| `lib/features/mono/mono_line_explanation_display.dart` | Map `MonoExplanationLine` to user-facing primary/secondary translation lines (source first, English optional). |
| `lib/features/mono/mono_screen.dart` | Wire `monoReaderTranslationEnabledProvider`; structured read page shows per-line translations when enabled. |
| `lib/features/settings/app_settings_prefs.dart` | Persist `nimon_mono_reader_translation_enabled` (default off). |
| `lib/features/settings/settings_providers.dart` | `monoReaderTranslationEnabledProvider`. |
| `lib/features/settings/settings_screen.dart` | New switch “Show Mono translations” + subtitle. |
| `test/features/profile/published_mono_detail_parser_test.dart` | Parser + display helper tests. |

## Stored JSON Shape

Published mono sentence rows mirror creator draft sentence JSON (`story_creator_draft_storage` / `StorySentenceItem`):

- `japaneseText` — full line string (UTF-16 indices for spans).
- `furiganaSpans` — `[{ "start", "end", "reading" }]` half-open on `japaneseText`.
- `meanings` — `{ "en": string?, "my": string?, "byLanguage": map? }` (`LocalizedMeanings`). **`my` holds the learner “source” language string** (same as creator UI).
- Optional legacy fallbacks on the same object: `sourceMeaning`, `englishMeaning`.

**Not parsed in this pass:** `meanings.byLanguage` free-form map (deferred; would need locale preference rules).

## Furigana Parsing

`rubyTokensFromPublishedSentenceContent` walks sorted valid spans, emits `MonoRubyToken` for span text + reading, and fills gaps with single-grapheme tokens (no reading), matching how `_lineToLayoutTokens` expects structured tokens. Invalid / out-of-range spans are skipped.

## Translation Parsing

`explanationFromPublishedSentenceContent` builds `MonoExplanationLine(en:, my:)` from `meanings`, then `sourceMeaning` / `englishMeaning` if `meanings` is absent.

`monoLineExplanationDisplay` shows **source (`my`) as primary**; when both source and English exist and differ, English is shown as a secondary muted line.

## Settings Toggle Wiring

- New preference: **`monoReaderTranslationEnabledProvider`**, default **`false`** (conservative).
- **MonoScreen** uses `ref.watch(monoReaderTranslationEnabledProvider)` for `showExplanation` passed through feeds / `_ReadingFeedPost`.
- Existing **Listening** toggle (`monoExplanationEnabledSettingProvider`) unchanged.

## Tests Added

`test/features/profile/published_mono_detail_parser_test.dart`:

- Ruby tokens from spans + gaps.
- Empty spans → empty token list (plain fallback preserved).
- Meanings + legacy keys.
- `buildMonoContentFromPublishedCore` integration cases.
- Display helper primary/secondary behavior.

## Flutter Analyze Result

Command:

```bash
flutter analyze lib/features/profile/data/published_mono_detail_parser.dart \
  lib/features/mono/mono_line_explanation_display.dart lib/features/mono/mono_screen.dart \
  lib/features/settings/app_settings_prefs.dart lib/features/settings/settings_providers.dart \
  lib/features/settings/settings_screen.dart test/features/profile/published_mono_detail_parser_test.dart
```

**New/edited files:** No issues for parser, `mono_line_explanation_display`, settings, or test file.

**`mono_screen.dart`:** Pre-existing infos/warnings (e.g. mock data `unnecessary_const`, unused `_legacyMockItems`, `characters` import policy). Not cleaned per scope.

## Flutter Test Result

| Command | Result |
|---------|--------|
| `flutter test test/features/profile` | Passed |
| `flutter test test/features/mono` | Passed |
| `flutter test` (full suite) | Passed |

## Remaining Risks

- **`meanings.byLanguage`** not surfaced.
- **Sentence-level legacy `reading`** field (single string) not merged into ruby tokens (only `furiganaSpans`).
- **Plain-body fallback path** (no structured `MonoContent`) still shows text only — unchanged.
- **`_MonoStructuredLineBlock`** still uses `showTranslation: false` for NimonSentenceBlock — unused for remote structured path after this work (reading uses `NimonRubyText` + new Column).

## Recommended Next Step

- Optional: migrate users who expected old “Mono explanation” behavior by one-time default or linking the two prefs.
- Parse `byLanguage` when product defines precedence rules.
