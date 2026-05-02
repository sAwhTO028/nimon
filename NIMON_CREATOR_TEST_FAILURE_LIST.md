# Nimon — creator-related test failures

**How this list was produced:** one `flutter test` run (no reruns, no code changes during the run) on:

- `test/create_shell_parent_child_flow_test.dart`
- `test/creator_progress_drawer_module_switching_widget_test.dart`
- `test/creator_drawer_session_vocab_embed_test.dart`

**Summary:** `15` passed, `3` failed. All failures are in `create_shell_parent_child_flow_test.dart`. The other two files had **no** failing tests in this run.

---

## Group A — `creatorDrawerSessionProvider.activeModule` not matching learn navigation

**Pattern:** After using the progress drawer to open a learn module (or switch), `activeModule` stays on the previous module instead of the expected one.

| Test file | Test name | Failure (short) |
|-----------|-----------|------------------|
| `test/create_shell_parent_child_flow_test.dart` | `Create shell parent-child verification 3-4. Switch to Vocabulary; Vocabulary local actions stay local` | Expected `CreatorModule.vocabulary`, actual `CreatorModule.storySentences` |
| `test/create_shell_parent_child_flow_test.dart` | `Create shell parent-child verification 5-10. Switch to Grammar/Quiz/Listening; local actions stay local` | Expected `CreatorModule.grammar`, actual `CreatorModule.vocabulary` |

---

## Group B — Back navigation / exit to Mono

**Pattern:** Second back from story sentences (after leaving learn `?panel=`) does not land on `/mono` as the test expects.

| Test file | Test name | Failure (short) |
|-----------|-----------|------------------|
| `test/create_shell_parent_child_flow_test.dart` | `Create shell parent-child verification 12. Back exits to Home Mono` | Expected `true` (URI starts with `/mono`), actual `false`; last location was `/create/story/sentences?draftId=…` |

---

## No failures in this run

| Test file | Notes |
|-----------|--------|
| `test/creator_progress_drawer_module_switching_widget_test.dart` | All tests passed in the run above. |
| `test/creator_drawer_session_vocab_embed_test.dart` | All tests passed in the run above. |

---

## Scope note

Other tests under `test/` that touch create/creator code (for example `remote_add_flow_smoke_test.dart`, `remote_delete_honesty_test.dart`) were **not** included in this single run. To extend this list, run those files explicitly and append results.
