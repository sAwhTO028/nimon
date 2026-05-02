# Add Paginated List — Cursor Prompt Template

Copy, fill placeholders, paste into Cursor when introducing a **new infinite list**.

---

```text
## Mandatory reading (before code)
Skim ALL of these and deep-read what's relevant:
- docs/NIMON_QUERY_PERFORMANCE_GUIDE.md
- docs/NIMON_API_QUERY_CONTRACT.md
- docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md
- docs/NIMON_CACHE_AND_REFRESH_POLICY.md
- docs/NIMON_PERFORMANCE_BUDGETS.md
- docs/NIMON_ARCHITECTURE_CONSTITUTION.md
- docs/NIMON_WIREFRAME_SCOPE_LOCK.md

Confirm this list is INSIDE PDF wireframe V1 scope — if uncertain, STOP and ask the user.

## Feature
Describe the list: [e.g. Profile → new “Collections” tab]

## Constraints
- Do NOT modify lib/main.dart routes unless user explicitly instructed.
- Do NOT delete/archive StoryRepo or mocks without migration instructions.
- Do NOT call AI/OpenAI/API from Flutter UI widgets directly.
- Network layer lives in repositories / backend clients — NEVER inside StatelessWidget.build().

## Deliverables checklist
1. **Summary DTO** only (see NIMON_API_QUERY_CONTRACT §4) — no nested heavy fields.
2. **Repository method** named per NIMON_REPOSITORY_PAGINATION_PATTERN (e.g. fetchXxxPage).
3. **PageResult / PageRequest** compatible shape (types may live incrementally beside repo).
4. **Riverpod (or equivalent) notifier** exposing:
   - items, isInitialLoading, isLoadingMore, isRefreshing, error, nextCursor, hasMore
   - in-flight duplicate guard + stale epoch/token for filter changes
   - refresh + loadMore
5. **UI states:** skeleton / empty / error / footer loader
6. **Search variant** debounced if searchable (performance guide)
7. **Tests** if risky (navigation + paging contract) — optional if user forbids scope

## Process
A) List FULL file paths you will create/modify BEFORE editing.
B) Smallest coherent diff — no unrelated refactors across mega-widgets unless asked.
C) flutter analyze MUST pass zero new error-severity issues.

## Output summary
Bullets: files touched, paging parameters, TTL/refresh behavior reference (cache doc).

Proceed.
```
