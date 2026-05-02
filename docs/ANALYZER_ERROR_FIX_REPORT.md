# Analyzer Error Fix Report

Date: 2026-05-01. Scope: **error-severity** analyzer issues only; no routing, mass cleanup, or behavior changes to live Mono / Add Story / Profile / Learn flows.

---

## Files Changed

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `flutter_lints: ^5.0.0` under `dev_dependencies` so `analysis_options.yaml` can resolve `package:flutter_lints/flutter.yaml`. |
| `lib/data/prompt_repository.dart` | Extended `PromptRepository.find` with optional `offset` (default `0`) and implemented pagination via `.skip(offset).take(limit)` so existing callers compile and batch loading behaves as intended. |
| `lib/features/story/story_screen.dart` | Replaced undefined `demoEpisodes` with a file-private `_StoryPageStub` list; replaced invalid `LearnHubScreen(story: …)` with the current `LearnHubScreen` API (`contentId`, `storyTitle`, `level`, `category`, `coverImageUrl`, `description`). |

**Not modified:** `analysis_options.yaml` (include line kept as required).

---

## Errors Fixed

1. **`lib/features/story/story_screen.dart`**
   - **`undefined_identifier`** `demoEpisodes` — fixed with `_kDemoStoryPages` (static placeholder copy only; screen remains orphaned from `GoRouter`).
   - **`undefined_named_parameter`** `story` on `LearnHubScreen` — fixed by passing supported named parameters derived from `widget.story`.

2. **`lib/ui/create/widgets/build_prompt_section.dart`**
   - **`undefined_named_parameter`** `offset` on `PromptRepository.find` — fixed by adding `offset` to `find` in `prompt_repository.dart` (smallest API-compatible change).

3. **`analysis_options.yaml` / `include_file_not_found`**
   - **`package:flutter_lints/flutter.yaml` cannot be resolved** — fixed by adding **`flutter_lints`** to **`pubspec.yaml`** `dev_dependencies` and running **`flutter pub get`**.

---

## Reasoning

- **`story_screen.dart`** is not registered in `main.dart`’s `GoRouter` (orphaned legacy). The goal was **compile-safety**, not product redesign: local stub pages preserve the existing PageView layout; the Learn FAB now opens **`LearnHubScreen`** with the same metadata the hub already accepts (`contentId`, titles, level, etc.), without changing routed Learn flows elsewhere.
- **`build_prompt_section.dart`** already assumed **`offset`** for pagination; **`PromptRepository.find`** had dropped that parameter. Restoring **`offset`** on the repository is smaller and safer than rewriting the widget’s loading strategy.
- **`flutter_lints`** belongs in **`dev_dependencies`** per Flutter template; this resolves the analyzer’s include without removing lint configuration.

---

## Flutter Pub Get Result

**Succeeded.** Dependencies resolved; `flutter_lints 5.0.0` was fetched (newer `6.0.0` noted as available by the resolver).

---

## Flutter Analyze Result

- **`dart format`** was run on: `lib/data/prompt_repository.dart`, `lib/features/story/story_screen.dart` only.
- **`flutter analyze`** completed with **423** reported issues total (same order of magnitude as before; mostly **info** / **warning** from existing deprecations, tests, and `tool/`).
- **`flutter analyze`** still exits with a **non-zero** status when *any* severity is present (infos/warnings included), which is expected until those are addressed or suppressed.

---

## Remaining Error-Severity Issues

**0** (confirmed by filtering `dart analyze` output: no `error` severity lines).

---

## Remaining Warning / Info Count

From the latest `dart analyze` run:

| Severity | Count |
|----------|------:|
| **warning** | **71** |
| **info** | **352** |
| **Total** | **423** |

---

## Risk Notes

- **`StoryScreen`** remains **unrouted**; the new stub text is **placeholder** only. If this screen is ever wired back into navigation, replace stubs with real episode data from **`StoryRepo`** / models.
- **`LearnHubScreen`** is a **`ConsumerStatefulWidget`**. The FAB still uses **`Navigator.push`** as before; it assumes a **`ProviderScope`** above the navigator (true for this app’s `main.dart`). No change to that pattern.
- **`PromptRepository.find(..., offset: n)`** now slices the filtered mock list; behavior matches the previous **caller intent** for paged loading without changing other call sites (they default **`offset`** to **0**).

---

## Recommended Next Step

1. Optionally run **`flutter analyze --no-fatal-warnings`** (or CI policy) if the goal is a green exit code while **info**/deprecation debt remains.
2. Triage the **71 warnings** (e.g. unused imports, test harness issues) in a separate hygiene pass—not mixed with error-only fixes.
3. Continue **Cleanup Wave 2** only when product-approved; do not use this pass as precedent for deleting **`story_screen.dart`**.
