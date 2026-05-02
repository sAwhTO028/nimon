# Draft Dirty State Post-Migration Verification

**Run date:** 2026-05-02  
**Environment:** Automated verification (Cursor agent shell). Host PostgreSQL at `localhost:5432` was **not reachable** from the runner (`P1001`), so migration **apply state vs. live DB** could not be confirmed here.

## Migration Status

| Item | Result |
|------|--------|
| Migration folder present | **Yes** — `nimon-backend/prisma/migrations/20260502120000_story_draft_dirty_flag/migration.sql` |
| SQL intent | Adds `hasUnpublishedCoreChanges BOOLEAN NOT NULL DEFAULT false` on `story_drafts`; sets `true` where `publishState <> 'draft'` |
| `prisma migrate status` (against `.env` `DATABASE_URL`) | **Not verified** — `Error: P1001: Can't reach database server at localhost:5432` |

**Local confirmation (required on your machine):** With PostgreSQL running and `DATABASE_URL` correct:

```bash
cd nimon-backend
node ./node_modules/prisma/build/index.js migrate status
```

Expect pending **none** if `20260502120000_story_draft_dirty_flag` is already applied; otherwise run `migrate deploy` (or your approved migration path) once the DB is up.

## Prisma Generate Result

**Passed.**

```text
cd nimon-backend
node ./node_modules/prisma/build/index.js generate
```

- Exit code: **0**  
- Client: **Generated Prisma Client (v7.7.0)**

## Backend Test Result

**Passed.**

```text
cd nimon-backend
node ./node_modules/jest/bin/jest.js src/modules/story-drafts/story-drafts.service.spec.ts
```

- Exit code: **0**  
- **1** suite, **10** tests passed

## Backend Build Result

`npm run build` was **not executed** — `npm` was not available on the runner PATH.

**Equivalent:** Nest production compile via Nest CLI succeeded:

```text
cd nimon-backend
node ./node_modules/@nestjs/cli/bin/nest.js build
```

- Exit code: **0**

On your machine, run:

```bash
cd nimon-backend
npm run build
```

## Flutter Analyze Result

**Completed with exit code 1** (analyzer reports issues; **no `error` severity lines** in this run).

- **227 issues** reported (mix of `info` and `warning`)
- **0 analyzer `error` diagnostics** observed in the analyzer output for this run

Command:

```text
cd <repo-root>
flutter analyze
```

## Flutter Test Result

**Passed.**

```text
cd <repo-root>
flutter test
```

- Exit code: **0**  
- **87** tests, all passed (`All tests passed!`)

## Manual Smoke Test Checklist

Run on a device/simulator against an environment where the migration **is** applied and API + DB match production-like config.

- [ ] **Create a new draft** → Workspace shows under **Drafts**
- [ ] **Publish read-only** → row becomes **synced** or **hidden** from Workspace (per product rules)
- [ ] **Edit the published draft** → row appears under **Editing**
- [ ] **Publish again** → row becomes **synced** or **hidden**
- [ ] **Published tab** — duplicate hide only applies to **Editing** rows (not Draft/Synced behavior)

## Risks

1. **DB connectivity / migration drift:** If `migrate status` is not re-run when Postgres is available, a environment could be running new app code against a schema missing `hasUnpublishedCoreChanges`.
2. **Existing published rows:** The migration sets `hasUnpublishedCoreChanges = true` for non-draft rows; confirm product expectations for list badges and workspace grouping after deploy.
3. **Flutter analyze noise:** Many `info`/`warning` findings are pre-existing; this run did **not** gate on “zero issues,” only on tests + absence of analyzer errors in the captured output.

## Recommended Next Step

1. Start PostgreSQL (or point `DATABASE_URL` at the target instance).  
2. In `nimon-backend`:  
   `node ./node_modules/prisma/build/index.js migrate status`  
   then apply pending migrations if any.  
3. Execute the **Manual Smoke Test Checklist** above on a staging build.  
4. Optionally tighten CI: fail `flutter analyze` only on `error` (or fix warnings in a separate change).
