# M13I Validation Translation Report

## Problem

After M13H, `app_ja.arb` and `app_my.arb` contained **English-mirrored** strings for all validation-related keys added from the template—functional but not V1-quality for Japanese and Myanmar users.

## Scope

- **ARB files only:** `lib/l10n/app_ja.arb`, `lib/l10n/app_my.arb`.
- No changes to `messageKey`, validators, `localized_validation_messages.dart` resolver logic, English fallback map, or UI layout.
- No hand-edits to generated `app_localizations_*.dart` (regenerated via `flutter gen-l10n`).

## Translation Style

See **`docs/M13I_VALIDATION_TRANSLATION_AUDIT.md`** for the Myanmar / Japanese style notes used during this pass.

## Myanmar Copy Pass

- Protected prompts, offline message, CTAs, auth, profile, collections, story basics, publish-sheet chrome, media strings, and common learn/publish strings were translated to concise Burmese UI copy.
- Placeholders `{min}`, `{max}`, `{actual}`, `{moduleLabel}` preserved where present in the English template.

## Japanese Copy Pass

- Same coverage as Myanmar: polite, compact です／ます調 suitable for in-app validation.
- Quiz/vocab/grammar strings translated conservatively for classroom-style UX.

## Placeholder Safety

- Parameterized ARB entries keep the same placeholder names as English.
- Tests assert placeholder names still appear in ja/my strings for sampled keys (`validationStorySentencesTooFew`, `validationStoryBodyTooLong`, `validationLearnCountVocabRange`).

## Mirror Tool Safety

`tool/mirror_arb_locales.dart` **only inserts keys missing from the target file**; it does not overwrite existing entries. Documented optional **`--dry-run`**. Manual ja/my translations are safe when re-running the tool after adding **new** keys to `app_en.arb`.

## Tests Added

- `test/l10n/validation_translation_coverage_test.dart` — spot keys differ from English for ja/my; placeholder preservation check.

## Commands Run

- `flutter gen-l10n`
- `dart format tool/mirror_arb_locales.dart`
- `flutter test test/l10n/validation_translation_coverage_test.dart`
- `flutter test test/core/validation test/core/media test/features/create/publish_validation_sheet_test.dart`
- `flutter test` (full suite)

## Manual Verification

1. Settings → App language → **Myanmar**: guest react → protected sheet; airplane mode → offline snack; invalid login field; story title error; publish validation sheet; invalid image type upload.
2. Repeat spot checks with **Japanese**.

## Remaining Risks

- Copy may benefit from **native speaker review** for tone (especially Myanmar compound UI strings and JLPT pedagogy terms).
- Future **new** ARB keys from the English template should be mirrored first, then translated in a follow-up pass.

## Recommended Next Step

Optional editorial pass with native reviewers; add CI grep or extend `validation_translation_coverage_test.dart` when new high-traffic keys ship.
