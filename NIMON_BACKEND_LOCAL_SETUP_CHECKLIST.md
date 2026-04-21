# Nimon — local backend development setup checklist

**Purpose:** Verify the machine is ready to **scaffold** a backend (Node toolchain, containers, git) before business logic.  
**Preference:** **Docker** for PostgreSQL (and Redis if needed) — avoid native DB installs on the host.

**Note:** Tooling was checked from the project environment (PowerShell). **Re-run the commands on your machine** after installing anything; paths differ per install.

---

## 1. Tool inventory

### Node.js

| Check | Result (automated scan) |
|-------|-------------------------|
| `node --version` | Reports **v22.22.0** |
| Executable resolved | **`c:\Program Files\cursor\resources\app\resources\helpers\node.exe`** (Cursor-bundled runtime) |
| `npm` / `corepack` on PATH | **Not found** |
| Typical `Program Files\nodejs` install | **Not found** on this scan |

**Interpretation:** A **standalone Node.js LTS** install (from [nodejs.org](https://nodejs.org/) or **nvm-windows**) is **still required** for backend work. Relying only on Cursor’s helper `node` is **not** sufficient — you need **`npm`** (or **pnpm** via Corepack) for packages and scripts.

**After installing Node LTS, verify:**

```powershell
where.exe node
node --version
npm --version
```

---

### pnpm (preferred) or npm

| Check | Result (automated scan) |
|-------|-------------------------|
| `pnpm --version` | **Not on PATH** |
| `npm --version` | **Not on PATH** |

**Setup once Node LTS is installed:**

```powershell
npm install -g pnpm
# or: corepack enable && corepack prepare pnpm@latest --activate
pnpm --version
```

---

### Docker Desktop

| Check | Result (automated scan) |
|-------|-------------------------|
| `docker --version` | **Not on PATH** |
| Default install paths | **Docker Desktop not found** under `Program Files\Docker` on this scan |

**Interpretation:** Install **[Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)** (WSL2 backend recommended). After install, confirm:

```powershell
docker version
docker run --rm hello-world
```

Do **not** start long-lived Postgres/Redis containers until the backend `docker-compose` exists — the `hello-world` check is enough to prove the engine works.

---

### Git

| Check | Result |
|-------|--------|
| `git --version` | **OK — `git version 2.52.0.windows.1`** |
| Works from terminal | **Yes** |

---

### Optional DB viewer (DBeaver / TablePlus / pgAdmin)

| Check | Result |
|-------|--------|
| Automated detection | **Not verified** (no scan of Start Menu / App Paths) |

**Optional for V1:** Install one when you first connect to a Dockerized Postgres. Not required to **scaffold** the repo.

---

## 2. Per-tool summary

| Tool | Installed? | Version (if known) | Works in terminal? | Missing steps |
|------|------------|--------------------|--------------------|---------------|
| **Git** | Yes | 2.52.0.windows.1 | Yes | — |
| **Node (system)** | **Unclear / likely no** | Only Cursor helper seen | `node -v` works via Cursor shim | Install **Node.js LTS**; ensure `where node` → `Program Files\nodejs\` or nvm path |
| **npm** | No (on PATH) | — | No | Comes with Node LTS installer |
| **pnpm** | No | — | No | `npm i -g pnpm` after Node |
| **Docker** | **Not detected** | — | No | Install Docker Desktop; add to PATH; finish `hello-world` |
| **DB viewer** | Unknown | — | — | Install when DB is up |

---

## 3. Docker usability (criteria)

| Step | Status |
|------|--------|
| Docker Desktop installed and running | **Not verified** (CLI missing here) |
| `docker` command | **Fails** until installed |
| Simple container (`hello-world`) | **Run after install** |

---

## 4. Minimum tools before backend code starts

### Required now

1. **Git** — already OK on scanned machine.
2. **Node.js LTS** (system install) + **npm** or **pnpm** — **required** for package management and scripts.
3. **Docker Desktop** + working **`docker` CLI** — **required** for Postgres (and later Redis) via compose.

### Optional later

- **DB GUI** (DBeaver, TablePlus, pgAdmin) — when inspecting schema/data.
- **Redis CLI** / GUI — only when the stack defines Redis.
- **API client** (Insomnia, Bruno, curl) — when endpoints exist.

---

## 5. Developer checklist (short)

### Ready now

- [x] **Git** installed and usable.
- [x] **Add flow API contract** documented (`NIMON_ADD_API_CONTRACT_V1.md`).

### Must install before backend scaffold (this machine)

- [ ] **Node.js LTS** (standalone) — verify `where node` points to `nodejs`, not only Cursor.
- [ ] **npm** or **pnpm** on PATH.
- [ ] **Docker Desktop** — `docker version` and `docker run --rm hello-world` succeed.

### Can skip for now

- [ ] DB GUI — add when DB runs.
- [ ] Postgres/Redis containers — start when `docker-compose.yml` exists.
- [ ] Production hosting / CI — after local scaffold.

---

## A. Ready to scaffold backend?

**No** — on the scanned environment, **Node (proper) + npm/pnpm + Docker** are not in a dev-ready state. After installing those three pillars and re-verifying, answer becomes **yes**.

---

## B. Missing items before backend scaffold

1. Standalone **Node.js LTS** with **npm** (or enable **pnpm**).
2. **Docker Desktop** with CLI working and **`hello-world`** successful.

---

## C. Recommended next step after setup

1. Re-run the verification commands in §1–3 and update this checklist.
2. Initialize the backend repo (e.g. `pnpm init`, TypeScript, lint) in a dedicated `backend/` or separate repository.
3. Add **`docker-compose.yml`** with **Postgres** (and Redis if required by stack) — then connect from the scaffold.

---

*Generated from automated checks + manual policy. Update the “Result” column after local installs.*
