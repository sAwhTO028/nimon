# Add AI-Powered Feature — Cursor Prompt Template

Use for **any** OpenAI/API-assisted capability (generation, extraction, scoring).

---

```text
## Mandatory docs
Read docs/NIMON_AI_FEATURE_PLAN.md and docs/NIMON_LANGUAGE_SYSTEM.md before coding.

## Feature
Describe AI capability: [e.g. suggest furigana for sentence]

## Non-negotiables
1. Flutter UI widgets MUST NOT call OpenAI or external AI HTTP endpoints directly.
2. Integration MUST go through:
   - nimon-backend endpoint OR
   - Dart AiRepository/AiService façade that only talks to our backend (not api.openai.com from device).
3. Separate fields:
   - Source Meaning / Learn Language output vs English Meaning (canonical bridge)—never overwrite user Source Meaning without explicit UX.

## Architecture sketch (fill in)
- Backend route: [METHOD /path]
- Request JSON fields: [...]
- Response JSON fields: [...]
- Auth: [session / bearer — keys only on server]

## Flutter layers
- Repository interface location: [lib/...]
- Widget only calls: repository.method()
- Loading/error UI uses App System Language strings (localization plan)—not inline English literals.

## Safety
- Human review step before publish: [required yes/no per product]
- Rate limit / quota: [backend responsibility — stub OK]

## Deliverable
1. List files to create/change BEFORE editing.
2. Implement backend stub + Flutter repository + one UI entry point (if requested).
3. Run flutter analyze.

If API keys or env files are needed, STOP and ask user—do not invent secrets.
```
