# Nimon dev run commands

Quick reference for **Postgres**, **Nest backend**, **Flutter** (local vs remote drafts), and **Prisma Studio**. Adjust paths if your clone layout differs.

---

## 1. Start Docker Postgres (and optional Redis)

From **`nimon-backend/`** (uses `docker-compose.yml`):

```bash
cd nimon-backend
docker compose up -d postgres
```

If you already have a container named **`nimon-postgres`** from a previous setup:

```bash
docker start nimon-postgres
```

Ensure **`nimon-backend/.env`** has a valid **`DATABASE_URL`** for that instance (see `.env.example`).

---

## 2. Start the Nest backend

From **`nimon-backend/`** (requires Node + install; see `package.json`):

```bash
cd nimon-backend
npm install
npm run start:dev
```

**npm shortcuts (same directory):** `npm run start:dev` (Nest watch), `npm run prisma:studio`, `npm run prisma:validate`, `npm run prisma:migrate:status`, `npm run prisma:generate`.

Default API URL in Flutter config: **`http://localhost:3000`**. For **Android emulator** talking to the host machine, run Flutter with  
`--dart-define=NIMON_API_BASE_URL=http://10.0.2.2:3000` (in addition to remote-draft flags if needed).

**Profile → Published (remote list):** The backend scopes `GET /v1/published-monos` by the Nest **`DEV_OWNER_ID`** (from `nimon-backend/.env`, or a default UUID). Flutter draft/publish calls must use the **same** logical owner via **`--dart-define=NIMON_DEV_OWNER_ID=<uuid>`** when it differs from the default. If these diverge, the Published tab can look **empty** even after a successful publish (no secret values belong in docs—set both sides to the same UUID in your local env).

---

## 3. Run Flutter — local-first (default)

Draft edits stay on **device storage**; **Prisma Studio will not** show those edits on **`story_drafts`**.

```bash
cd ..   # repo root (parent of nimon-backend)
flutter pub get
flutter run
```

---

## 4. Run Flutter — remote draft mode

Syncs drafts to the API/Postgres after successful calls. **Prisma Studio** can show **`story_drafts`** / **`draft_sentences`** changes after saves.

```bash
flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

Strict (fail loudly on remote errors instead of silent local fallback):

```bash
flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true
```

---

## 5. Open Prisma Studio

From **`nimon-backend/`** (requires `DATABASE_URL` in `.env` and a reachable Postgres):

```bash
cd nimon-backend
npm run prisma:studio
```

Equivalent: `node ./node_modules/prisma/build/index.js studio`.

**Expectation:** Studio shows **database** state only. In **local-first** Flutter mode, creator Basics/Sentences edits **do not** appear here until you use **remote drafts** (or another writer updates the DB).

---

## 6. Optional shell aliases (Flutter)

There is **no** `package.json` at the **Flutter repo root** (only `nimon-backend/`). Flutter `dart-define` flags are long; if you prefer shortcuts, define **aliases in your shell** (not committed), for example:

**Bash / zsh** (`~/.bashrc` / `~/.zshrc`):

```bash
alias nimon-flutter='cd /path/to/nimon && flutter run'
alias nimon-flutter-remote='cd /path/to/nimon && flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true'
alias nimon-flutter-remote-strict='cd /path/to/nimon && flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true'
```

**PowerShell** (`$PROFILE`):

```powershell
function nimon-flutter-remote { Set-Location C:\path\to\nimon; flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true @args }
```

Adjust paths to your clone.

---

## Further reading

- [NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md](NIMON_V1_CONTENT_LIFECYCLE_STANDARD.md) — lifecycle and modes.
- [NIMON_CONTENT_LIFECYCLE_AUDIT.md](NIMON_CONTENT_LIFECYCLE_AUDIT.md) — implementation audit.
- [DEV_WORKFLOW_SHORTCUTS_REPORT.md](DEV_WORKFLOW_SHORTCUTS_REPORT.md) — what shortcuts exist and why.
