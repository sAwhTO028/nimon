# Nimon Architecture Constitution

**Audience:** Human maintainers and Cursor AI agents.  
**Binding:** Treat this document as **non-negotiable defaults** unless the product owner explicitly overrides in writing.  
**Wireframe authority:** Product flows must align with the **uploaded PDF wireframe**; this constitution summarizes engineering guardrails around that scope.

---

## 1. Project Goal

Build **Nimon**, a Flutter application for **Japanese story consumption and creation**, with **Mono** as the primary reading surface, **Create** for authoring, **Profile** for identity and saved/published work, **Learn** for pedagogy tied to content, and **Settings** for app-wide preferences—including **app language** and learn/source language behavior—while leaving room for **future AI-assisted** creation without coupling UI to raw providers.

---

## 2. Current V1 Product Scope

**In scope for V1 engineering work:**

| Area | Router / entry (reference) | Notes |
|------|----------------------------|--------|
| **Home Mono** | `/mono`, `/mono/search`, `/mono-reader` | Vertical feed + reader; wireframe is source of layout priority. |
| **Add Story / Create** | `/create`, `/create/story/basics`, `/create/story/sentences` | Drafts, panels (vocab/grammar/quiz/listening embed), publish path. |
| **Profile / More** | `/more`, `/profile/public`, `/profile/share`, notifications, followers/following | Tabs (published/saved/workspace, etc.) per wireframe. |
| **Learn** | `/learn/:id...` | Only when **connected** to mono/learn navigation or creator panels. |
| **Settings** | `/settings`, `/settings/help` | Includes theme/locale/reading scale patterns already in app. |
| **Auth** | `/login` | Entry gate as wired in `lib/main.dart`. |

**Out of scope for V1 unless explicitly revived:** legacy discovery HomeScreen, old library, see_more, old story detail stack, old writer lab, `create_mono` prototype, and other paths documented in `docs/NIMON_WIREFRAME_SCOPE_LOCK.md`.

---

## 3. Valid Feature Areas (Folder Boundaries)

| Zone | Primary location | Responsibility |
|------|------------------|----------------|
| **Mono** | `lib/features/mono/` | Feed, reader, search, mono-specific models. |
| **Create** | `lib/features/create/` | Story authoring, drafts, DTOs, remote draft repo. |
| **Profile** | `lib/features/profile/` | Profile tabs, public profile, published mono fetch. |
| **Learn** | `lib/features/learn/` | Hub, grammar, vocab, quiz, listening routes. |
| **Settings** | `lib/features/settings/` | App prefs, locale/theme hooks. |
| **Shared UI** | `lib/ui/reading/`, `lib/core/`, `lib/widgets/` | Design tokens, reusable reading widgets, dock. |
| **Data** | `lib/data/` | Repositories, mocks—**must** stay behind interfaces where remote exists. |
| **Backend (TS)** | `nimon-backend/` | HTTP APIs, auth, drafts, published monos—**AI must not bypass** for production secrets. |

---

## 4. Forbidden Changes for AI Coder

Unless the user gives an **explicit, scoped instruction**:

1. **Do not** delete, rename, or mass-move files without an audit report and approval (`docs/CLEANUP_WAVE_2_PLAN.md` pattern).
2. **Do not** change **`lib/main.dart`** routing tables without explicit request.
3. **Do not** call **OpenAI or third-party AI HTTP APIs directly from Flutter widgets**—use service/repository/backend abstraction (`docs/NIMON_AI_FEATURE_PLAN.md`).
4. **Do not** mix **app UI strings** with **learn/source meaning** or **English meaning** fields—see `docs/NIMON_LANGUAGE_SYSTEM.md`.
5. **Do not** revive **legacy** flows documented in [`docs/NIMON_WIREFRAME_SCOPE_LOCK.md`](docs/NIMON_WIREFRAME_SCOPE_LOCK.md) without product approval.
6. **Do not** remove **`StoryRepo` / mock / singleton** contracts without a migration plan—Mono and Profile depend on `repo` today.
7. **Do not** hardcode new user-visible English (or any language) strings in widgets—follow `docs/NIMON_STRING_LOCALIZATION_PLAN.md`.

---

## 5. Folder Structure Rules

- **Feature-first:** New screens belong under `lib/features/<feature>/`.
- **Shared presentation:** Cross-feature widgets go under `lib/ui/` or `lib/shared/` with clear naming—not duplicated per feature.
- **Models:** Domain types live under `lib/models/` or feature-local `data/` when feature-specific—avoid parallel conflicting types for the same concept.
- **No orphan barrels:** Avoid expanding `lib/ui/ui.dart`-style mega-barrels; prefer explicit imports for live paths.
- **Backend:** NestJS modules stay under `nimon-backend/src/modules/` with DTOs co-located.

---

## 6. Routing Rules

- **Single source of truth:** `GoRouter` configuration in `lib/main.dart` (or extracted router file **only if** user asks to extract—do not split proactively).
- **Shell:** Mono + Profile use the **stateful shell** pattern already present; full-screen routes (create, learn) stay outside shell as today.
- **Deep links:** Preserve query parameters (`draftId`, `tab`, `panel=`) when touching creator/profile navigation helpers.
- **No orphan routes:** Do not register routes for legacy surfaces without product sign-off.

---

## 7. State Management Rules

- **Riverpod** is standard: `Provider`, `StateNotifierProvider`, `StateProvider` as already used.
- **Creator session:** Drawer/route sync logic is sensitive—small, tested changes only.
- **Avoid global singletons** beyond established patterns (`repo`, scaffold messenger key)—prefer injection via providers when adding major features.

---

## 8. Repository / Service Rules

- **Interfaces:** Abstract repositories (`StoryDraftRepository`, etc.) with local + remote implementations.
- **HTTP:** Use `package:http` or backend client in **repository layer**, not in widgets.
- **AI (future):** All AI calls go through **backend or `Ai*` service façade**—never from `build()` methods.
- **Caching / prefs:** SharedPreferences for client-only flags; **etag / draft** logic stays in repositories.

---

## 9. Backend / API Rules

- **Secrets:** API keys live on **server** or CI—not in Flutter assets.
- **Contracts:** DTOs in Flutter should mirror backend DTOs (`story-draft`, `published-mono`).
- **Versioning:** Prefer additive JSON fields for backward compatibility.

---

## 10. Testing Rules

- **Widget / integration tests** under `test/`—extend when changing navigation or creator drawer behavior.
- **Golden tests** optional—only if user requests visual regression.
- **Analyze:** `flutter analyze` must stay **error-free** before merge (warnings acceptable per project policy).

---

## 11. Cleanup Rules

- **Audit before delete:** Produce a markdown report; follow `docs/CLEANUP_WAVE_2_PLAN.md` philosophy.
- **Never delete** `story_repo`, `episode_mock_data`, or core story models without explicit migration—Mono/Profile depend on them.
- **Legacy archive** is a **product decision**, not an AI default action.

---

## 12. Performance Rules

- **God screens:** Prefer incremental extraction from `mono_screen.dart` / `story_creator_sentences_screen.dart` over growing single files—coordinate with user.
- **Lists:** Use lazy builders; avoid unbounded `Column` of heavy children.
- **Audio:** Reuse single player patterns (`just_audio`)—do not spawn redundant players without disposal review.

---

## 13. How to Add a New Feature Safely

1. Read **`docs/NIMON_WIREFRAME_SCOPE_LOCK.md`**—confirm the feature is **in wireframe / approved**.
2. Read **`docs/NIMON_LANGUAGE_SYSTEM.md`** if the feature shows learner/creator text or bilingual fields.
3. Add routes **only** with user approval for router edits.
4. Place UI under the correct `lib/features/<area>/`.
5. Add providers/repositories beside existing patterns.
6. Run **`flutter analyze`**; add tests for navigation/state if risky.
7. Use **`ai_prompts/ADD_NEW_FEATURE_PROMPT.md`** as a checklist.

---

## 14. How to Add a New Category Safely

See **`ai_prompts/ADD_NEW_CATEGORY_PROMPT.md`**: update enums/config, filters, mock/repo mapping, backend taxonomy if applicable, and UI chips consistently.

---

## 15. How to Add AI-Assisted Features Safely

See **`docs/NIMON_AI_FEATURE_PLAN.md`** and **`ai_prompts/ADD_AI_FEATURE_PROMPT.md`**: backend-first, abstraction layer, separate **Source Meaning** vs **English Meaning**, no direct widget API calls.

---

## Revision

Update this constitution when wireframe PDF or V2 scope changes; reference the revision date in commit messages.
