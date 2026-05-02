# Nimon Cursor Master Prompt

Copy everything inside the block below into Cursor when starting substantial work on the Nimon Flutter repo.

---

```text
You are working on the Nimon Flutter application (solo-maintainer + Cursor). Follow these rules FIRST—before editing code.

## Read architecture docs (mandatory)
Before writing or refactoring Dart/backend code, read (skim minimum; deep-read sections relevant to the task):
- docs/NIMON_ARCHITECTURE_CONSTITUTION.md
- docs/NIMON_WIREFRAME_SCOPE_LOCK.md
- docs/NIMON_LANGUAGE_SYSTEM.md
- docs/NIMON_STRING_LOCALIZATION_PLAN.md (if touching UI copy)
- docs/NIMON_AI_FEATURE_PLAN.md (if touching AI-related behavior)

## Wireframe & scope
- V1 valid flows: Mono home, Add Story/Create, Profile/More, Learn (when connected), Settings. Legacy surfaces listed in NIMON_WIREFRAME_SCOPE_LOCK.md must NOT be revived unless the user explicitly approves.
- Do NOT change lib/main.dart routing unless the user explicitly asks.
- Do NOT delete or archive files unless the user explicitly asks (cleanup uses audit-first prompts).

## Language rules
- App UI strings ≠ Learn/Source Meaning ≠ English Meaning ≠ Japanese content. See docs/NIMON_LANGUAGE_SYSTEM.md.
- Do not hardcode new user-visible UI strings in widgets; prefer centralized l10n strategy in docs/NIMON_STRING_LOCALIZATION_PLAN.md.

## AI rules
- Never call OpenAI/third-party AI APIs directly from Flutter widgets. Use backend or repository/service abstraction (docs/NIMON_AI_FEATURE_PLAN.md).

## File safety
1. List files you intend to touch BEFORE editing (paths relative to repo root).
2. Touch ONLY files necessary for the task—no drive-by refactors, no unrelated formatting sweeps.
3. Prefer smallest diff that solves the request.
4. After edits: run `flutter analyze` and fix any NEW error-severity issues you introduced.

## Repository constraints
- Preserve StoryRepo / repo singleton contracts unless the user supplies a migration plan.
- Backend secrets stay on server—never commit API keys into Flutter.

## Deliverable
- Summarize what changed and why in plain language.
- If blocked by ambiguity, ask one concise question instead of guessing product behavior.

Now proceed with the user’s task.
```

---

## Usage notes

- Paste the block at the **top of a new chat** or pin it in Cursor Rules / project README pointer.
- For targeted tasks, also paste **`ADD_NEW_FEATURE_PROMPT.md`** or the specialized prompts from `ai_prompts/`.
