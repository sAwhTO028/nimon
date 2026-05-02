# Optimize Query Performance — Cursor Audit Prompt Template

Use when a screen feels **slow**, **janky**, or triggers **heavy network**, **duplicate calls**, or **unnecessary rebuilds**.

---

```text
## Phase 1 — AUDIT ONLY (no code edits yet unless user overrides)
Goal: Produce a PERFORMANCE_AUDIT_FINDINGS.md (or paste into chat) BEFORE modifying Dart.

Mandatory reading snippets:
- docs/NIMON_QUERY_PERFORMANCE_GUIDE.md
- docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md
- docs/NIMON_CACHE_AND_REFRESH_POLICY.md
- docs/NIMON_PERFORMANCE_BUDGETS.md

## Target screen/module
[user: path/feature name, e.g. lib/features/profile/profile_screen.dart Published tab]

## Audit checklist — answer each bullet with evidence (file + line references)
1. Where are network/repo calls initiated? (__initState, notifier, listeners, tap handlers — NOT build?)
2. What is the payload shape returned to the UI? Summary vs Detail leak?
3. Are there duplicate/overlapping in-flight GETs during scroll/tab switch?
4. Does provider invalidation cause whole-tree reloads unnecessarily?
5. List rendering: Fixed item extent? Separate heavy subtrees inside itemBuilder?
6. Image sizing: thumbnails vs full-res leakage on feed rows?
7. JSON parsing/transforms on main isolate excessively large lists?
8. Search input: debounced or storms requests?
9. Audio / Quiz / Learn data accidentally prefetched?

## Constraints
- Do NOT refactor unrelated mega-widgets/files.
- Do NOT change routing/pubspec/backend in this audit pass unless explicitly requested AFTER report.
- If fix requires risky architectural change → recommend phased plan.

## Phase 2 — FIX (ONLY after report approved by user)
- Smallest incremental fix addressing top bottleneck first.
- Re-run flutter analyze.
- Optionally add instrumentation (Timeline / prints behind kDebugMode only—remove before merge unless user agrees).

Produce the AUDIT FINDINGS FIRST.
```
