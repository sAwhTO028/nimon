# M17 session checkpoint report

Checkpoint summary for the M17 milestone line (owner catalog, quotas, loading UX, detail stats, guest gating). This document is a **session snapshot** for handoff and QA planning.

**Checkpoint last updated:** `2026-05-14` (session snapshot; phone-verified list below).

---

## Completed milestones (current)

### M17C — Owner Published Monos pagination

- Owner **Published** monos pagination fixed (cursor / list behavior aligned with product expectations).
- Header uses **`totalCount`** from the list response where available.
- List loading pattern verified as **10 + 10 + 1** (first page, second page, remainder) for typical catalog sizes.
- **Stale backend restart** behavior documented (e.g. cursor / count drift after restart without migration); see dedicated M17C/M17E notes in repo docs as referenced during that work.

### M17D — V1 free product quota standard

- **V1 free product quota** standard finalized and documented.
- Limits: **Published 30**, **Saved 50**, **Collections 10**, **Collection items 30**, **Drafts 50**.

### M17E — Backend quota guards

- Backend **quota guards** implemented for protected actions.
- **Final published quota rule** uses **Published tab visible count + 1 > 30** (restore/publish path aligned with catalog visibility, not a naive raw DB total alone).
- **DB count 29** allows upload after a **clean backend restart** when visible tab count is below the limit.
- **30** visible published (non-trash catalog) **blocks** with **`quota_exceeded`** (or equivalent keyed response) when the next action would exceed the cap.

### M17F — Flutter quota exceeded UX

- Flutter **`quota_exceeded`** (and related) response **parser** wired for user-facing flows.
- **Localized** quota / limit alerts surfaced in the app per the M17F standard.

### M17H — Blocking loading overlay

- **Standard blocking loading overlay** added for high-stakes creator flows: **publish**, **update**, **restore**, **delete**, **cancel** (and related paths as scoped in M17H), so users do not double-submit or navigate in ambiguous states.

### M17J — Real mono detail stats + Learn badge

- **Published** and **Saved** mono **detail / options** metrics use **real** backend / DTO fields for **likes**, **duration / read time**, and **category** (no fabricated defaults such as fixed “2m” or type-derived “Story/Article” labels when server data exists).
- **Learn** hub badge copy updated to **Manual** / **Creator-made** (V1 manual packages), with localization as delivered in M17J.

### M17K — Guest mode sign-in gating

- **Guest** users: **Add** and **Profile** dock targets show the **existing** protected-action sign-in flow and **do not** navigate to Create or Profile until authenticated.
- **Following** tab guest state: **Sign in** CTA and copy; **dark mode** text uses **theme semantic colors** (`onSurface` / `onSurfaceVariant`) for readable contrast.

### M17L — Auth startup routing (cold start)

- **Valid saved login session** opens **Home Mono** directly on app restart; login chrome is not shown first; **Guest** does not act as accidental session entry after hydration (see `docs/M17L_AUTH_STARTUP_ROUTING_FIX_REPORT.md`).

---

## Phone-verified (this checkpoint)

The following were **verified on phone** at this checkpoint:

- **Saved tab pagination** loads beyond **20** items and the **spinner stops** when loading completes.
- **Published** and **Saved** mono **detail sheets** show **real stats** (likes, duration/read time, category, etc., aligned with server data).
- **Learn** hub card shows **Manual** / **Creator-made** as intended.
- **Guest** mode: **Add** and **Profile** **sign-in gates** work (sign-in sheet / flow; no silent navigation past gate).
- **Following** tab **guest empty state** is **readable in dark mode**.
- **Valid saved login session** opens **Home Mono** directly on **app restart** (cold start).

---

## Open issues (current)

- **None confirmed** at this checkpoint.

---

## Handoff note

For deep dives per sub-milestone, prefer the individual **`docs/M17*_*.md`** implementation and audit reports in this repo where they exist; this checkpoint file is intentionally high-level.
