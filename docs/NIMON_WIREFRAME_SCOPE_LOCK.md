# Nimon Wireframe Scope Lock

**Authority:** The **uploaded PDF wireframe** defines the **valid user journeys** for Nimon V1. This document locks **engineering scope** to that intent and lists **legacy surfaces that must not be revived** without explicit product approval.

---

## 1. V1 Valid Flows (Engineering Alignment)

These align with the **live `GoRouter` shell** in `lib/main.dart` and the product draft—exact labels/layouts follow the PDF:

| Flow | Valid routes / surfaces | Engineering anchor |
|------|-------------------------|---------------------|
| **Home Mono** | Mono feed, reader, search | `/mono`, `/mono/search`, `/mono-reader`, `MonoScreen` |
| **Add Story** | Create hub, basics, sentences + workspace panels | `/create`, `/create/story/basics`, `/create/story/sentences` |
| **Profile** | My profile, public profile, tabs per wireframe | `/more`, `/profile/public`, share, notifications, followers/following |
| **Learn** | Hub + modules when **connected** from Mono/creator | `/learn/:id...` tree |
| **Settings** | App preferences, help | `/settings`, `/settings/help` |
| **App language** | UI locale | Settings + `locale` on `MaterialApp` (existing providers) |
| **Learn / source language** | Explanation language for pedagogy fields | Creator/learn UX + entity fields (`docs/NIMON_LANGUAGE_SYSTEM.md`) |
| **Auth** | Login / guest entry per wireframe | `/login` |

**Future AI story creation** is **planned** per `docs/NIMON_AI_FEATURE_PLAN.md`—must **not** bypass wireframe review when shipped.

---

## 2. Out-of-Scope / Legacy Flows (Do Not Revive By Default)

The following exist in the repo but are **not** part of V1 wireframe navigation. They must **not** be reconnected to `GoRouter`, restored as “secondary homes,” or expanded—**unless** the product owner explicitly approves a scope change **and** the PDF is updated.

| Legacy area | Location (approx.) | Why legacy |
|-------------|-------------------|------------|
| **Old discovery HomeScreen** | `lib/features/home/**` | Superseded by **Mono** as home (`/mono`). |
| **Old library** | `lib/features/library/**` | No valid V1 route; not in wireframe lock. |
| **See more / filters** | `lib/features/see_more/**` | Tied to old discovery; not V1 shell. |
| **Old story detail / episode reader stack** | `lib/features/story/**`, parts of `lib/features/reader/**`, legacy episode sheets | Not the Mono reader path. |
| **Old writer lab** | `lib/features/writer/**` | Not in V1 wireframe. |
| **`MoreScreen` stub** | `lib/features/more/**` | Live profile is **`ProfileScreen`** on `/more`. |
| **`create_mono` prototype** | `lib/create_mono/**` | Parallel create UX—not the shipped create flow. |
| **Mega UI barrel + old one-short sheets** | `lib/ui/ui.dart`, `add_mono_bottom_sheet.dart`, etc. | Discovery-era composition; do not wire back without approval. |

**Reference:** `docs/NIMON_PROJECT_AUDIT_REPORT.md`, `docs/CLEANUP_WAVE_2_PLAN.md`.

---

## 3. Legacy Code Rules

1. **No revival** of legacy routes or “temporary” navigation into legacy screens without **written product approval** and wireframe update.
2. **Cleanup** (archive/delete) must **preserve** Mono → Create → Profile → Learn → Settings ordering from the PDF—never remove or reorder shell tabs without approval.
3. **Bugfixes** inside legacy files are **low priority** unless they break the build; prefer **not** investing new features there.

---

## 4. Cleanup vs Wireframe

- **Cleanup waves** reduce debt but **must not** change **user-visible flow** away from the PDF without sign-off.
- Any mechanical archive/delete PR must include **smoke verification** of:
  - Mono feed open → read
  - Create draft → sentences → save/publish path (as wired)
  - Profile tabs
  - Learn entry from mono/creator as implemented

---

## 5. Cursor Default

When unsure whether a file is **legacy**, check:

1. Is it imported from `lib/main.dart`’s route widgets or their transitive imports?
2. If **no**, treat as **legacy or optional** until proven otherwise.

---

## 6. Revision

Update this lock when the **PDF wireframe** changes version; note **date** and **approver** in git history.
