# M14 V1 Release QA Hardening Report

## Scope

This report records **M14** automated verification (backend + Flutter), **dart format** normalization, a **minimal analyzer hygiene** fix (two unused imports), and explicitly defers **device-only** matrices (Parts D–K) to **operator execution** using `docs/M14_V1_RELEASE_QA_HARDENING_PLAN.md`.

No validation rules, localization keys, or backend schema were changed for M14 beyond the trivial Dart import cleanup above.

## Commands Run

**Backend** (`nimon-backend`):

```bash
pnpm jest --runInBand
pnpm nest build
```

(Equivalent: `node ./node_modules/jest/bin/jest.js --runInBand` and `node ./node_modules/@nestjs/cli/bin/nest.js build` if `pnpm` is unavailable.)

**Flutter** (project root):

```bash
flutter gen-l10n
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

**Follow-up after import fix:**

```bash
dart format lib/ui/bottom_sheets/episode_bottom_sheet.dart test/features/profile/profile_published_mono_trash_repository_test.dart
flutter test test/features/profile/profile_published_mono_trash_repository_test.dart test/widget_test.dart
```

**Device smoke (operator; not run in M14 agent session):**

```powershell
flutter run `
  --dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true `
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

Backend env per plan: listen `0.0.0.0:3000`, `MEDIA_PUBLIC_BASE_URL=http://192.168.11.5:3000/uploads`, `NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000`.

## Backend Result

| Step | Result |
|------|--------|
| **Jest** (`pnpm jest --runInBand` or `node .../jest.js --runInBand`) | **PASS** — 25 suites, **228** tests |
| **Nest build** (`nest build`) | **PASS** (exit code **0**) |

Auth, profile PATCH validation, collections, drafts, publish paths, media validation, and `validation_failed` shape are covered by existing backend tests; manual API smoke remains optional per plan.

## Flutter Result

| Step | Result |
|------|--------|
| **`flutter gen-l10n`** | **PASS** (exit **0**; `l10n.yaml` drives options) |
| **`dart format --set-exit-if-changed .`** | **First run:** reformatted **50** files (repo had drift, including `archive/legacy_v1_discovery/`, `lib/`, `test/`, `tool/`). **Second run:** **PASS** — 431 files, **0** changed. |
| **`flutter analyze`** | Completes with **119 issues** (exit **1**): **0** `error -`, **21** `warning -`, **98** `info -` (post-import-fix counts). |
| **`flutter test`** (full suite) | **PASS** — **526** tests, “All tests passed!” |

### Existing analyzer warnings (exact list, 21)

After M14 import cleanup, `flutter analyze` still reports these **`warning -`** entries:

1. `lib/features/create/create_story_basics_form.dart:980` — `unused_element` (`_buildStepPreviewCard`)
2. `lib/features/create/story_creator_grammar_editor_screen.dart:1022` — `unused_element` (`_HowItWorksBullet`)
3. `lib/features/create/story_creator_grammar_editor_screen.dart:1056` — `unused_element` (`_GrammarReviewListCard`)
4. `lib/features/create/story_creator_grammar_overlays.dart:192` — `unused_element` (`_HowItWorksBullet`)
5. `lib/features/create/story_creator_progress_checklist.dart:127` — `unused_element_parameter` (`trailingNote`)
6. `lib/features/profile/profile_screen.dart:77` — `unused_element_parameter` (`processingStatusLabel`)
7. `lib/features/profile/profile_screen.dart:300` — `unused_field` (`_processingMock`)
8. `lib/features/profile/profile_screen.dart:398` — `unused_field` (`_publishedLoadedRemote`)
9. `lib/features/profile/profile_screen.dart:1246` — `unused_element` (`_showProcessingDraftSheet`)
10. `lib/features/profile/profile_screen.dart:3515` — `unused_element_parameter` (`tagline`)
11. `lib/features/profile/profile_screen.dart:3887` — `unused_element` (`_OneShortList`)
12. `lib/features/profile/profile_screen.dart:3896` — `unused_element_parameter` (`trailingAction`)
13. `lib/features/profile/profile_screen.dart:3897` — `unused_element_parameter` (`onItemTap`)
14. `lib/features/profile/profile_screen.dart:4402` — `unused_element_parameter` (`key`)
15. `lib/features/profile/profile_screen.dart:5036` — `unused_element_parameter` (`denseBadge`)
16. `lib/features/reader/episode_reader_screen.dart:13` — `unused_element` (`_mockEpisodeText`)
17. `lib/shared/widgets/cards/oneshot_badged_card.dart:266` — `unused_element` (`_formatLikes`)
18. `test/create_shell_parent_child_flow_test.dart:50` — `override_on_non_overriding_member`
19. `test/episode_action_bar_test.dart:27` — `unused_local_variable` (`saveCalled`)
20. `test/episode_action_bar_test.dart:28` — `unused_local_variable` (`shareCalled`)
21. `test/episode_action_bar_test.dart:29` — `unused_local_variable` (`startCalled`)

### Existing analyzer infos (summary)

**98** `info -` issues remain, dominated by:

- `deprecated_member_use` (`withOpacity`, `describeEnum`, `Radio`/`groupValue`, `surfaceVariant`, form `value`, etc.)
- `use_build_context_synchronously`
- `dangling_library_doc_comments`, `unnecessary_import`, `curly_braces_in_flow_control_structures`, `prefer_initializing_formals`, `unnecessary_const`, `unnecessary_brace_in_string_interps`, `no_leading_underscores_for_local_identifiers`
- `avoid_print` in `tool/` scripts

No new **error**-severity issues were introduced in M14.

## Device Smoke Result

**Not executed** in the M14 automation session (no attached device / LAN backend in scope). Operator should run **Part D** and **Phone Smoke Matrix** from the plan and record pass/fail per row.

## Auth / Guest Result

**Not executed** (manual). Use plan **Part E**.

## Creator Flow Result

**Not executed** (manual). Use plan **Part F**. Automated coverage includes remote draft/publish flows in tests (e.g. `remote_add_flow_smoke_test.dart`).

## Full Learn Result

**Not executed** (manual). Use plan **Part G**.

## Reader Result

**Not executed** (manual). Use plan **Part H**.

## Profile / Social Result

**Not executed** (manual). Use plan **Part I**.

## Media Result

**Not executed** (manual). Use plan **Media Upload Matrix** / **Part J** item 9. Backend media validation covered by Jest where applicable.

## Validation / Localization Result

**Automated:** `flutter gen-l10n` succeeded; `test/l10n/validation_translation_coverage_test.dart` and related l10n tests passed in the full **526** run.

**Manual:** **Part J** (en / my / ja spot checks) not run in this session.

## Offline Result

**Not executed** (manual). Use plan **Part K**.

## Fixes Applied

| Change | Rationale |
|--------|-----------|
| Removed unused import `reader_screen.dart` from `lib/ui/bottom_sheets/episode_bottom_sheet.dart` | Clears `unused_import` analyzer warning; no runtime behavior change. |
| Removed unused import `published_mono_dto.dart` from `test/features/profile/profile_published_mono_trash_repository_test.dart` | Clears `unused_import` warning; tests re-run green. |

**Dart format:** One-time application across the tree so `dart format --set-exit-if-changed .` is clean for CI/release gates (50 files were reformatted on first run).

## Remaining Risks

- **Device-only** regressions (share URL host, media on LAN, airplane mode, guest prompts) require physical smoke.
- **Disk space** on Windows/Android build hosts can still fail native builds (known from prior sessions).
- **Analyzer exit code 1** while **0 errors**: teams treating `flutter analyze` as a hard gate may need `--no-fatal-warnings` / `analysis_options` policy, or a follow-up chore to clear the **21** warnings above.

## Release Readiness

| Gate | Status |
|------|--------|
| Backend tests + build | **Ready** (automated green) |
| Flutter gen-l10n + format + tests | **Ready** (automated green) |
| Flutter analyze (strict CI) | **Attention** — **119** issues, **0 errors**; **21** warnings documented |
| Device + manual matrices | **Pending operator** |

**Overall:** **Conditional go** for engineering after device smoke sign-off; no automated release blockers were observed in backend or Flutter tests.

## Recommended Next Step

1. Operator runs **Parts D–K** on a phone against `192.168.11.5:3000` with the dart-defines in the plan.  
2. Fill **Final Sign-off Checklist** in `docs/M14_V1_RELEASE_QA_HARDENING_PLAN.md`.  
3. Optionally schedule a follow-up chore to reduce the **21** remaining **warnings** (unused private UI helpers / test locals) so `flutter analyze` exits **0** under stricter CI.

---

## Part O — Output summary

| Question | Answer |
|----------|--------|
| QA plan created? | **Yes** — `docs/M14_V1_RELEASE_QA_HARDENING_PLAN.md` |
| Backend tests passed? | **Yes** — 228 tests |
| Backend build passed? | **Yes** |
| Flutter gen-l10n passed? | **Yes** |
| Flutter analyze passed? | **Partial** — **0 errors**, **119** total issues (**21** warnings, **98** infos); exit code **1** |
| Flutter full test passed? | **Yes** — **526** tests |
| Phone smoke passed? | **N/A (operator)** — not run in M14 session |
| Auth/guest passed? | **N/A (operator)** |
| Creator read-only publish passed? | **N/A (operator)** — automated remote smoke tests passed |
| Full learn publish passed? | **N/A (operator)** |
| Reader/social passed? | **N/A (operator)** |
| Media upload passed? | **N/A (operator)** |
| Validation/localization passed? | **Automated tests yes**; **manual Part J N/A** |
| Offline passed? | **N/A (operator)** |
| Blockers fixed? | **No release blockers found** in automated runs; **2** trivial unused-import warnings fixed |
| Release readiness? | **Conditional** — pending device/manual sign-off per plan |

---

## M14B follow-up — Dark mode surface polish (Flutter)

**M14B** addressed dark-mode contrast and bottom-sheet overflow on profile tabs, Create add tab, learn hub / vocab / grammar lists, creator quiz & listening modules, and shared help sheets. See `docs/M14B_DARK_MODE_SURFACE_POLISH_AUDIT.md` and `docs/M14B_DARK_MODE_SURFACE_POLISH_REPORT.md`. Targeted `flutter test` (profile / create / learn) and full `flutter test` were run after the change set.
