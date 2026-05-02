# Cleanup Safe — Cursor Prompt Template

Use for **debt reduction** without breaking wireframe scope.

---

```text
## Read first
docs/NIMON_ARCHITECTURE_CONSTITUTION.md
docs/NIMON_WIREFRAME_SCOPE_LOCK.md
docs/CLEANUP_WAVE_2_PLAN.md (if applicable)

## Cleanup goal (narrow)
[One sentence: e.g. remove unused import warnings in features/learn only]

## Hard rules
1. AUDIT FIRST: produce a markdown report listing candidates, importers, and risk—do NOT delete until user approves report.
2. NO mass delete of folders without explicit user instruction matching the report.
3. Do NOT delete or refactor: lib/data/story_repo.dart, story_repo_mock.dart, repo_singleton.dart, episode_mock_data.dart, core story models—unless user supplies migration plan.
4. Do NOT change lib/main.dart routing unless user explicitly asks.
5. Preserve V1 flows: Mono, Create, Profile, Learn, Settings per wireframe.

## Allowed actions this session
- [ ] Delete only explicitly listed files after grep confirms zero importers
- [ ] Archive (git mv) only if user explicitly says so
- [ ] Format / fix imports / analyzer warnings in scoped paths only: [paths]

## Verification
After changes: dart format on touched files; flutter analyze; smoke reasoning for Mono + Create + Profile.

## Output
1. Short audit table (file → importers → decision).
2. Diff summary.
3. flutter analyze result (errors must remain zero if currently zero).

If anything touches StoryRepo or routing, STOP and ask user.
```
