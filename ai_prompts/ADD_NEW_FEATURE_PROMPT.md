# Add New Feature — Cursor Prompt Template

Copy and fill in the bracketed sections, then paste into Cursor.

---

```text
## Context (read first)
I am adding a feature to Nimon. Read docs/NIMON_ARCHITECTURE_CONSTITUTION.md and docs/NIMON_WIREFRAME_SCOPE_LOCK.md before coding.

## Feature summary
[One paragraph: what the user can do, which flow (Mono / Create / Profile / Learn / Settings)]

## Wireframe / product approval
- [ ] Confirmed this matches the PDF wireframe OR user explicitly approved deviation: [yes/no]
- If deviation: [describe]

## Scope boundaries
- Allowed routes to touch: [e.g. none | ProfileScreen only | new widget under features/profile]
- Forbidden: [e.g. do not change GoRouter | do not touch create drawer sync]

## Files (list BEFORE editing)
[List explicit paths: lib/...]

## Data / language
- Uses App UI strings only / learner content fields / both: [pick]
- If learner fields: specify sourceMeaning vs englishMeaning per docs/NIMON_LANGUAGE_SYSTEM.md: [notes]

## Implementation checklist
1. Implement minimal UI + state under correct lib/features/<area>/.
2. No direct AI HTTP from widgets (docs/NIMON_AI_FEATURE_PLAN.md).
3. No new hardcoded UI strings without following docs/NIMON_STRING_LOCALIZATION_PLAN.md.
4. Run flutter analyze; fix new errors.

## Tests
- [ ] Widget/integration test needed: [yes/no — why]

Implement now.
```
