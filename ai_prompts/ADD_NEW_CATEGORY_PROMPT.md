# Add New Story Category — Cursor Prompt Template

Use when introducing or renaming a **story category** (Love, Comedy, …) across UI, filters, models, and backend.

---

```text
## Read first
docs/NIMON_ARCHITECTURE_CONSTITUTION.md, docs/NIMON_WIREFRAME_SCOPE_LOCK.md, docs/NIMON_LANGUAGE_SYSTEM.md (only if category affects labels vs content).

## Goal
Add or rename category: [DISPLAY_NAME]

## Scope
- Wireframe still defines category list: [yes/no — if no, user approved]

## Checklist — update ALL relevant surfaces (do not skip)

### 1. Config / single source of truth
- [ ] Flutter enum or const map: [file path — e.g. lib/core/story_categories.dart or models/story_category.dart]
- [ ] Ensure display name + API/backend slug mapping documented in one place.

### 2. UI
- [ ] Create flow: category chips / picker / basics form — [files]
- [ ] Mono feed: filters / level chips — [files]
- [ ] Profile / published cards if shown — [files]

### 3. Models & parsing
- [ ] JSON/backend ↔ app parsing for category field — [files]
- [ ] Null/unknown category fallback behavior defined.

### 4. Backend (if applicable)
- [ ] nimon-backend DTO validation / enum alignment — [modules]
- [ ] Migration note if DB enum changes.

### 5. Assets (if category has artwork)
- [ ] assets/images/... paths consistent with pubspec
- [ ] No broken Image.asset paths.

### 6. Tests
- [ ] Unit/widget test for parsing or filter — [yes/no]

## Forbidden
- Do not change lib/main.dart routes unless explicitly requested.
- Do not delete legacy folders as part of this task.

## Deliverable
1. List files changed (paths).
2. Summary of mapping: displayName ↔ wire/API value.
3. flutter analyze clean of new errors.

Implement with smallest safe diff.
```
