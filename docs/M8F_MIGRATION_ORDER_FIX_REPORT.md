# M8f Migration Order Fix Report

**Problem:** Two creator-collection migration folders existed:

| Folder | Role |
|--------|------|
| `20260507045402_creator_mono_collections` | **ALTER only** — drops DB defaults on `id` and `updatedAt`. |
| `20260507130000_creator_mono_collections` | **CREATE** — creates `creator_mono_collections` and `creator_mono_collection_items`. |

Prisma applies migrations in **lexicographic order** of the folder name. Because `20260507045402` sorts **before** `20260507130000`, a **new database** would run the ALTER **before** the CREATE and fail (`relation does not exist`).

**App / Flutter code:** unchanged (per task). **No new migration SQL file** beyond reordering: the ALTER steps are the same bytes as before.

---

## Which migration creates tables?

- **`prisma/migrations/20260507130000_creator_mono_collections/migration.sql`**  
  - `CREATE TABLE "creator_mono_collections"`  
  - `CREATE TABLE "creator_mono_collection_items"`  
  - indexes + foreign keys.

## Which migration alters tables?

- Previously: **`20260507045402_creator_mono_collections/migration.sql`** (removed from the repo — see below).  
- Now: **`20260508120000_creator_mono_collections_alter_defaults/migration.sql`**  
  - Same SQL as the old ALTER migration (byte-for-byte match of the previous `migration.sql` body).

Lexicographic order is now:

1. `20260507130000_creator_mono_collections` → **CREATE**  
2. `20260508120000_creator_mono_collections_alter_defaults` → **ALTER**  

So **`migrate deploy` on a fresh database applies CREATE, then ALTER.**

---

## Was the bad-order migration deleted or retained?

- **Deleted:** folder `20260507130000` was **not** deleted — the CREATE migration **stays**.  
- **Deleted:** folder **`20260507045402_creator_mono_collections`** (entire directory).  
- **Added:** folder **`20260508120000_creator_mono_collections_alter_defaults`** with the same ALTER statements as the old file.

So the **ALTER** migration was **retained** (same SQL), **renamed/re-timestamped** so it sorts **after** the CREATE migration.

---

## Databases that already applied `20260507045402_*`

If `migrate status` reports a **missing migration** for `20260507045402_creator_mono_collections` (file removed from disk), **one row** in `_prisma_migrations` still references the old name.

**Safe repair (SQL, run once per environment that had the old migration applied):**

```sql
UPDATE "_prisma_migrations"
SET "migration_name" = '20260508120000_creator_mono_collections_alter_defaults'
WHERE "migration_name" = '20260507045402_creator_mono_collections';
```

- The new `migration.sql` is **identical** to the old ALTER file → Prisma’s migration checksum for that migration body should still match (verify with `pnpm prisma migrate status` after updating `.env` with valid DB credentials).

If Prisma reports a **checksum mismatch** for that row, see [Prisma: P3009 / checksum](https://www.prisma.io/docs/guides/migrate/troubleshooting-development) and use `prisma migrate resolve` as documented for your Prisma version, or update the `checksum` column only if your team’s procedure allows it after verifying the on-disk SQL matches what was applied.

**Do not** run `prisma migrate reset` on production.

---

## Is fresh DB migration safe?

**Yes**, with this repo state:

1. `20260507130000` runs → tables exist.  
2. `20260508120000` runs → defaults dropped → aligns with `schema.prisma` (`@default(uuid())`, `@updatedAt` without relying on DB defaults for those columns).

Validate on a **throwaway** database only:

```bash
cd nimon-backend
pnpm prisma migrate deploy
pnpm prisma generate
pnpm prisma migrate status
```

---

## Is current DB migration status clean?

- **In this session:** `pnpm` was not on `PATH`; Prisma CLI was run with `node ./node_modules/prisma/build/index.js`. Earlier, `migrate status` reported the database was up to date (`8` migrations) against `localhost:5432` / `nimon`. After filesystem changes, re-run **`pnpm prisma migrate status`** (or the `node … migrate status` form) **after** applying the SQL `UPDATE` above if your DB had applied `20260507045402`.

- **Authentication:** subsequent `migrate status` / `db execute` calls failed with **P1000** in the automation environment (credentials vs `.env`). **Run status locally** with your real `DATABASE_URL`.

---

## Tests / build results (automation run)

| Command | Result |
|---------|--------|
| `node ./node_modules/prisma/build/index.js generate` | **Success** |
| `node ./node_modules/@nestjs/cli/bin/nest.js build` | **Success** (exit 0) |
| `node_modules/.bin/jest.cmd src/modules/creator-collections` (Windows) / `pnpm jest src/modules/creator-collections` | **Success** — 11 tests passed |
| `node_modules/.bin/jest.cmd` (full suite) | **Success** — 15 suites, 126 tests passed |
| `pnpm prisma migrate deploy` / `migrate status` against your DB | **Run locally** — use the `_prisma_migrations` `UPDATE` above if the old migration name was applied; then confirm **`migrate status`** is clean. |

**Note:** Invoking Jest via `node ./node_modules/jest/bin/jest.js` failed in this environment with a Prisma client resolution error; **`node_modules/.bin/jest.cmd`** (or `pnpm jest`) resolved correctly.

---

## Summary table (requested output)

| Question | Answer |
|----------|--------|
| **Which migration creates tables?** | `20260507130000_creator_mono_collections` |
| **Which migration alters tables?** | `20260508120000_creator_mono_collections_alter_defaults` (same ALTER as former `20260507045402`) |
| **Was the bad-order migration deleted or retained?** | The **folder** `20260507045402_*` was **removed**. The **ALTER SQL** was **retained** under **`20260508120000_*`**. |
| **Is fresh DB migration safe?** | **Yes** — CREATE runs before ALTER by name order. |
| **Is current DB migration status clean?** | Run `migrate status` after the **`UPDATE _prisma_migrations`** fix if the old migration name was recorded. This workspace could not confirm DB auth. |
| **Tests / build result** | `prisma generate` OK, `nest build` OK, `jest` creator-collections **11/11**, full Jest **126/126** (via `jest.cmd` / `pnpm jest`). |

---

## Reminder

- Total migration count remains **8** (one folder removed, one added).  
- **No** duplicate `CREATE` migrations; **no** app/Flutter edits.
