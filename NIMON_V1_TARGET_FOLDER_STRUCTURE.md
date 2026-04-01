# NIMON V1 — Target Folder Structure

**Summary:** This document proposes a **target** `lib/` layout for a simplified **Version 1** of the NIMON Flutter app. It reflects your stated product direction (Mono as main entry, Add for one-short create, Profile, Learn as a supporting screen from Mono) and maps **today’s codebase** (see `PROJECT_STRUCTURE_REPORT.md`) to **where code should conceptually live** after a future reorganization. **No files have been moved or renamed** to produce this document.

---

## Proposed `lib/` folder tree (V1 target)

Below is a **practical, feature-first** layout suitable for a solo developer—not enterprise clean architecture.

```
lib/
├── main.dart                    # runApp, MaterialApp.router, top-level GoRouter (or thin delegate to app/)
├── app/
│   ├── app.dart                 # Optional: NimonApp widget if split from main
│   ├── router.dart              # GoRoute definitions, ShellRoute, redirects
│   └── shell/                   # Bottom nav / tab scaffold for V1 (Mono | Add | Profile + auth flow)
│       └── v1_app_shell.dart    # Name as you prefer; single shell for V1
├── core/
│   ├── theme/
│   │   └── app_theme.dart       # ThemeData, typography (today: inline + google_fonts)
│   ├── constants/
│   │   └── app_constants.dart   # Strings, timeouts, feature flags (minimal)
│   └── utils/                   # Small helpers (e.g. share, formatting)—only if shared
├── data/
│   ├── repositories/            # Interfaces + implementations
│   │   ├── auth_repository.dart
│   │   ├── mono_repository.dart
│   │   ├── create_repository.dart # one-short submission / drafts
│   │   └── profile_repository.dart
│   ├── mock/                    # Mock implementations (swap for API later)
│   │   └── ...
│   └── providers.dart           # Optional: Riverpod/global accessors if you keep ProviderScope
├── models/
│   ├── user.dart
│   ├── mono_item.dart           # Name to match product; align with existing mono/story models
│   └── create_draft.dart        # Whatever one-short needs for V1
├── features/
│   ├── auth/
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   └── widgets/
│   │   └── README or notes: V1 = email/password + guest path; OAuth later
│   ├── mono/
│   │   ├── presentation/
│   │   │   ├── mono_screen.dart          # Main entry after login
│   │   │   ├── widgets/
│   │   │   └── start_mono_sheet.dart     # If still used in V1
│   │   └── mono_routes.dart              # Optional: feature-local route helpers
│   ├── learn/
│   │   └── presentation/
│   │       ├── learn_hub_screen.dart     # Opened from Mono (“deeper explanation”)
│   │       └── widgets/
│   ├── create/
│   │   └── presentation/
│   │       ├── create_one_short_screen.dart  # V1 scope: one-short only
│   │       └── widgets/                      # Prompt cards, paper UI, etc.
│   └── profile/
│       └── presentation/
│           ├── profile_screen.dart
│           └── widgets/
└── shared/
    ├── widgets/                 # Buttons, app bars, loading/error—only truly cross-feature
    └── ui/                      # Optional barrel: bottom sheets shared by Mono + Create
```

**Note:** You may flatten `presentation/` if you prefer `features/mono/mono_screen.dart` directly—this tree shows one level of grouping only if the feature grows.

---

## Section-by-section explanation

### `lib/main.dart` + `lib/app/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| `main.dart` | Single entry: `runApp`, `ProviderScope` (if used), delegates to router/theme. | **Critical** |
| `app/router.dart` | All `GoRouter` paths in one place: auth gate, `/mono`, `/create` (one-short), `/profile`, `/learn/...`. Easier to see V1 surface area than scattering routes only in `main.dart`. | **Critical** (can stay in `main.dart` until you split) |
| `app/shell/` | V1 bottom navigation: **Mono | Add (create) | Profile**; Learn is **not** a tab—pushed from Mono. | **Critical** |

**NIMON today:** Router and `AppShell` live in `main.dart`; duplicate `lib/app/app_shell.dart` exists but is unused—a V1 cleanup would consolidate under `app/` once you rework navigation.

---

### `lib/core/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| `theme/` | Colors, `ThemeData`, text styles—one source of truth (today split between `main.dart` and `core/theme.dart`). | **Critical** |
| `constants/` | App-wide constants (e.g. max title length for one-short)—avoid magic numbers in features. | **Optional but small** |
| `utils/` | Cross-cutting helpers **only** if two or more features need them. | **Optional** |

Avoid dumping feature logic here.

---

### `lib/data/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| `repositories/*.dart` | Contracts your UI calls: `AuthRepository`, `MonoRepository`, etc. | **Critical** |
| `mock/` | Implementations backed by local JSON, `Future.delayed`, `SharedPreferences`—**same interfaces** as future API clients. | **Critical** until backend exists |
| Optional `api/` later | `Dio`/`http` client, interceptors, base URL—add when backend is real. | **V2+** (structure only) |

**Backend readiness:** UI and features depend on **repository interfaces**, not on `StoryRepoMock` by name. Today NIMON uses `repo_singleton.dart` and `StoryRepo`—V1 can narrow to smaller repos or adapt the same pattern with clearer names (`MonoRepository` wrapping what you still need from stories/mono).

---

### `lib/models/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| Shared **DTOs / entities** (user, mono card, one-short payload) | Serializable shapes used by repositories and multiple features. | **Critical** |
| Feature-only UI state | Prefer keeping inside the feature if not reused. | **Avoid** in `models/` |

**NIMON today:** Rich models (`story`, `episode`, `mono`, …). V1 keeps only models **Mono, Create, Profile, Auth, and Learn** actually need; the rest become **legacy** (see §4).

---

### `lib/features/auth/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| Login, guest entry, future OAuth UI | Isolated auth flow; no mono/create code mixed in. | **Critical** |

**Current file:** `lib/features/auth/login_screen.dart`.

---

### `lib/features/mono/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| **Main entry screen** after auth, navigation into Learn, links to your mono content list | This is the **product home** for V1—not `HomeScreen`. | **Critical** |

**Current files:** `lib/features/mono/mono_screen.dart`, `start_mono_sheet.dart`. Router today points `/mono` to a placeholder—V1 product intent means **this feature becomes the primary tab**.

---

### `lib/features/learn/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| `LearnHubScreen` and supporting widgets | **Supporting** screen opened from Mono (deeper explanation)—not a main tab. | **Critical** (as secondary route) |

**Current file:** `lib/features/learn/learn_hub_screen.dart`.

---

### `lib/features/create/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| **One-short creation only** for V1: prompts, paper UI, submit/draft | Matches “Add = create one-short content.” Split from story series / AI stories. | **Critical** (narrow scope) |

**Current spread:** `lib/features/create/create_screen.dart` (very large), `lib/ui/create/`, `lib/create_mono/`. V1 target is to **conceptually own** one-short under `features/create/` (and fold or slim `create_mono` into it over time).

---

### `lib/features/profile/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| Basic profile: avatar, name, stats, sign-out | Matches “Profile = basic user/profile screen.” | **Critical** |

**Current file:** `lib/features/profile/profile_screen.dart`.

---

### `lib/shared/`

| What lives here | Why | V1 |
|-----------------|-----|-----|
| Widgets used by **3+ features** or obvious design-system pieces | Prevents `features/mono` importing `features/create` for a button. | **Use sparingly** |

**NIMON today:** `lib/shared/widgets/`, `lib/ui/`, `lib/widgets/story_card.dart`—V1 would gradually consolidate **truly shared** pieces here; feature-specific sheets stay under the feature or `shared/ui` only if both Mono and Create need them.

---

## V1 core vs V2 / later vs legacy

### V1 core (ship focus)

- **`features/auth`** — Login / guest / session entry.
- **`features/mono`** — Main tab, entry to Learn when needed.
- **`features/learn`** — Secondary, from Mono.
- **`features/create`** — One-short only (Add).
- **`features/profile`** — Basic profile tab.
- **`app/`** — Router + V1 shell (Mono | Add | Profile).
- **`data/`** + **`models/`** — Repositories + models **for those features only** (mocks first).
- **`core/theme`** (and minimal constants).

### V2 or later (keep out of V1 main UX; code may still exist during transition)

- **`features/home`** — Discovery feed, challenges, community—explicitly **not** V1 main scope.
- **`features/library`** — Following writers, saved lists.
- **Long-form reading:** `features/story`, `features/reader`, writer flows, episode stacks.
- **`create_mono` story series, AI stories** — Not V1 “Add” scope.
- **`features/see_more`**, heavy **filters**, **quiz** if not product-critical.
- **`features/settings`** — “Settings-heavy flows” deferred; a **minimal** profile settings row might still live under Profile in V1.

### Archive / legacy / experimental (today’s repo reality)

- **`lib/app/app_shell.dart`** — Legacy navigator shell; unused by current `main.dart`.
- **`lib/features/more/more_screen.dart`** — Superseded by routing Profile to `/more` or unified Profile.
- **`story_screen.dart`** if unrouted / duplicate of detail.
- Duplicate **episode bottom sheet** modules (`features/widgets` vs `ui/bottom_sheets`) — technical debt, not a V1 feature boundary.
- **`create_mono/README.md`** — Module docs; verify against V1 routing.

---

## Backend readiness (simple, not over-engineered)

1. **Repositories in `lib/data/repositories/`** — One interface per concern (auth, mono, create, profile). Implementations in `data/mock/` now, `data/api/` later with the **same** interface.
2. **No extra layers** — Skip `domain/`, `usecases/`, `entities/` unless one file per feature becomes unmanageable. A **repository + model** is enough for NIMON V1.
3. **Android + iOS** — Same Flutter `lib/`; only `android/` and `ios/` store native config. No duplicate business logic in platform folders.
4. **Environment** — Later: `const baseUrl` or `--dart-define` / flavor-specific `lib/core/config.dart`—add when you have a real API.
5. **State** — `StatefulWidget` + repositories is fine; **Riverpod** only where it already pays off (e.g. create flow) to avoid two global patterns.

---

## Avoid over-engineering (explicit)

- **Do not** add `domain/usecases/entities` unless the team grows or features explode.
- **Do not** create a package per feature inside one app.
- **Do not** mirror every current file 1:1 into the new tree—this document is a **target**; migration can be incremental.
- **Do** keep **one router file** (or `main.dart`) readable for a solo dev.
- **Do** keep **Learn** as a **route**, not a fourth bottom tab, to match “hidden/supporting.”

---

## Final recommendation

1. **Treat V1 navigation as:** Auth → **Mono (default tab)** → Add (one-short) → Profile; **Learn** pushed from Mono only.
2. **Gradually fold** today’s `create_screen.dart` / `create_mono` / `ui/create` into **`features/create`** with **one-short-only** surface in the router.
3. **Park** Home, Library, story reader, series, AI stories under a **`legacy/` or feature flags** mindset until V2—either physically move later or leave in place but **exclude from V1 router and shell**.
4. **Standardize data access** on **repository interfaces** in `lib/data/` so swapping mocks for HTTP is a **file swap**, not a rewrite of Mono/Create/Profile screens.

This structure is **specific to NIMON** (mono-centric product, existing `mono_screen`, `learn_hub_screen`, `login_screen`, `profile_screen`, large `create`/`create_mono` split) while staying **small enough for one developer** to own.

---

*Documentation only. No code or routes were modified to create this file.*
