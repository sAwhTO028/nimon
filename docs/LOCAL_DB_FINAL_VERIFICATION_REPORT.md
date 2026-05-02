# Local DB Final Verification Report

**Date:** 2026-05-02  
**Environment:** Local Docker Postgres (`nimon-postgres`), `nimon-backend` Prisma CLI, Flutter repo root.  
**Constraints honored:** No application code changes, no destructive SQL, no warning cleanup.

## Migration Status

Commands (from `nimon-backend`):

```bash
node ./node_modules/prisma/build/index.js migrate status
```

**Result:** Exit code **0**. Prisma reported **2** migrations in `prisma/migrations` and:

**`Database schema is up to date!`**

No pending migrations at verification time.

## Prisma Generate Result

```bash
node ./node_modules/prisma/build/index.js generate
```

**Result:** **Passed** (exit code **0**). Prisma Client **v7.7.0** generated successfully.

## Backend Test Result

```bash
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts
```

**Result:** **Passed** — **1** suite, **10** tests, exit code **0**.

## Backend Build Result

```bash
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Result:** **Passed** (exit code **0**).

## Flutter Analyze Result

```bash
flutter analyze
```

(from repository root)

**Result:** Completed with **227** reported issues (`info` / `warning`). **No `error`-severity diagnostics** were present in the analyzer output for this run. Exit code **1** reflects non-zero issue count, not necessarily compile-breaking errors.

## Flutter Test Result

```bash
flutter test
```

**Result:** **Passed** — **87** tests, **All tests passed!**, exit code **0**.

## StoryDraft Table Check

**Prisma schema:** `StoryDraft` includes `hasUnpublishedCoreChanges`:

```67:69:c:\Users\owner\Desktop\SAW_PROJ\nimon\nimon-backend\prisma\schema.prisma
  /// True when publishState is not `draft` and working copy may differ from last published snapshot.
  /// New rows default false; migration sets true for existing non-draft rows (conservative).
  hasUnpublishedCoreChanges Boolean @default(false)
```

**Live database (read-only):** `information_schema.columns` for `public.story_drafts` returned a row for column name **`hasUnpublishedCoreChanges`** (confirmed via `docker exec … psql`).

## Prisma Migrations Check

**Live database (read-only):** `_prisma_migrations` contains a row whose **`migration_name`** is:

**`20260502120000_story_draft_dirty_flag`**

(Queried with `SELECT migration_name … WHERE migration_name LIKE '%20260502120000%'` inside the Postgres container.)

Together with **`migrate status`** reporting the DB up to date, the dirty-flag migration is **confirmed applied** for this environment.

## Manual Smoke Test Checklist

End-to-end behavior still depends on API + app build; automated checks above do not replace device flows.

- [ ] Create a new draft → Workspace shows under **Drafts**
- [ ] Publish read-only → row **synced** or **hidden** from Workspace (per product rules)
- [ ] Edit published draft → row under **Editing**
- [ ] Publish again → **synced** or **hidden**
- [ ] **Published** tab: duplicate hide applies only to **Editing** rows

## Risks

1. **Single-machine proof:** This report reflects one local DB; staging/prod must be verified separately.
2. **Flutter analyze noise:** Many findings are pre-existing infos/warnings; CI policy may still treat non-zero analyze exit as failure.
3. **Data semantics:** Migration sets `hasUnpublishedCoreChanges` for existing non-draft rows; confirm UX matches expectations for legacy rows.

## Recommended Next Step

Run the **Manual Smoke Test Checklist** against the backend the Flutter app points to (same `DATABASE_URL` / API base URL). If staging exists, repeat **`migrate status`** and a minimal API smoke there before release.
