# M8 Discovery And Polish Closeout Report

This report closes the **M8 discovery and polish** milestone described in `docs/M8_DISCOVERY_AND_POLISH_PLAN.md`, building on the social/profile foundation documented in `docs/M7_SOCIAL_PROFILE_POLISH_CLOSEOUT_REPORT.md`.

**Scope:** documentation synthesis only (no app or backend code changes in this document).

---

## Completed Scope

| Track | Deliverable | Primary reference |
|-------|-------------|-------------------|
| **M8a** | UserId-canonical public profile routing; legacy `?creator=` fenced to debug/mock; release rejection path | `docs/M8A_USERID_ROUTING_CLEANUP_REPORT.md` |
| **M8b** | Paginated **followers** API + Flutter pager; `/profile/followers` remote-backed (mock list removed) | `docs/M8B_FOLLOWERS_LIST_REPORT.md` |
| **M8c** | **Collections / Saved** product decision: **Saved-only flat list** recommended for V1 | `docs/M8C_COLLECTIONS_DECISION_SPEC.md` |
| **M8c1** | Saved-only **Flutter** polish: copy, demo folder gating, Profile Saved remote tab | `docs/M8C1_SAVED_ONLY_POLISH_REPORT.md` |
| **M8d** | Social **count** presentation (`formatSocialCount`, Mono rail + story options, public profile chips) | `docs/M8D_SOCIAL_COUNT_UI_POLISH_REPORT.md` |
| **M8e** | Share snackbars + core social gate strings centralized (`NimonAppStrings`); clipboard share retained | `docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md` |

Together, M8 addresses the M7 deferrals called out in the discovery plan: **routing hygiene**, **followers parity**, **collections decision**, **count polish**, and **share/copy centralization** (with full i18n still deferred).

---

## UserId Routing Cleanup

- **Canonical production path:** `/profile/public?userId=<uuid>` for real creator profiles (remote repository).
- **Mono** navigation continues to use `creatorProfileLocation` with **`allowLegacyHandle: false`** so feed-driven opens prefer **`writerId`**.
- **Legacy `?creator=`:** supported for **debug / mock** profiles only when policy helpers allow; **release** builds without `userId` show an explanatory screen instead of the mock bundle.
- **Owner preview:** signed-in “View public profile” pushes with **`userId`** when available.
- **Tests:** `public_profile_routing_policy_test.dart`, existing `creator_profile_location_test.dart` (see M8a report).

---

## Followers List

- **Backend:** `GET /v1/users/:userId/followers` with cursor pagination (aligned with following-list patterns). Service tests and Nest build reported clean in M8b.
- **Flutter:** `RemoteUserFollowRepository.fetchFollowersPage`, `profileFollowersPagerProvider` family, `ProfileConnectionsScreen` followers tab wired to remote data; row taps deep-link **`/profile/public?userId=`**.
- **Auth:** guest gate on followers; following tab behavior unchanged from M7.
- **Note:** M8b intentionally made the followers list **public** for any user id; product should revisit if private accounts land later (M8b remaining risks).

---

## Collections Decision

- **Decision:** **Option A — Saved-only (flat list)** for **V1**, matching existing **`MonoBookmark`** uniqueness and **`GET /v1/me/bookmarks`**.
- **Deferred:** named **collections/folders**, tags, and smart collections are documented as **post-V1** forks unless product expands scope (see M8c spec §6–8).
- **M8c1** implemented the Flutter side of that decision: production remote paths avoid misleading folder/collection copy; demo bookmark folders remain **debug-gated**.

---

## Saved-only Polish

- Central policy: `monoDemoBookmarkFoldersEnabled` (see `saved_only_ux_policy.dart`).
- **Mono:** Save / Saved / Remove from Saved copy; bookmark toggle only on remote-style builds; demo seeds and collection sheet disabled when not in demo mode.
- **Profile Saved (remote):** guest and empty states + list actions use `SavedLibraryCopy` (bookmark snack strings later alias **`NimonAppStrings`** in M8e).
- **Tests:** saved-only policy, story options saved-only panel, copy constants; bookmark API tests remain in `remote_mono_social_repository_test.dart`.

---

## Social Count UI Polish

- **`formatSocialCount`** for compact display (0–999, `K`, `M` rules).
- **Mono reader rail:** under React, show **`React`** when likes are **0**; otherwise show abbreviated count; notifier stays in sync with optimistic react toggle.
- **Story options:** Likes metric uses real **`item.likesCount`** and formatter (including **0** in that context).
- **Public profile:** follower/following (and mock header stats) use the same formatter; optimistic follow still updates follower count UX.
- **Tests:** `format_social_count_test.dart`, `social_count_ui_behavior_test.dart` harnesses.

---

## Share / Localization Polish

- **Share:** Still **clipboard** of canonical **`shareUrl`**; snack text driven by **`NimonAppStrings`** (`shareLinkCopied`, `shareLinkUnavailable`). **`share_plus`** not added (product approval deferred).
- **Copy holder:** **`lib/l10n/nimon_app_strings.dart`** centralizes M8e-listed strings; **`SavedLibraryCopy`** aliases bookmark-related entries for a single source of truth.
- **Full l10n:** No ARB / `gen-l10n` yet; `MaterialApp` already lists **`en` / `ja`** with stock Flutter delegates—user-visible custom strings remain **English** until ARB migration.

---

## Tests Summary

- **M8a:** routing policy + creator location tests (see M8a report); profile/mono suites green at M8a closeout (**322** tests noted there).
- **M8b:** backend Jest on user-follow module; Flutter repository + followers pager tests.
- **M8c1:** saved-only policy, story options, `saved_library_copy_test`; social repository tests for bookmarks unchanged.
- **M8d:** formatter + lightweight optimistic UI harness tests.
- **M8e:** `share_mono_link_test` (canonical URL + `NimonAppStrings` snack text), `nimon_app_strings_gate_test`.
- **Aggregate:** Full **`flutter test`** reported **all passed** at **M8e** closeout (**344** tests per `docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md`). Later runs may show a higher count as tests accumulate; the milestone expectation is **maintain green CI** on the full suite.

---

## Remaining Risks

- **Public followers list** visibility vs future privacy settings (M8b).
- **Cold deep links** with only `?creator=` in release until marketing URLs or a resolver move to `userId` (M8a).
- **Mock notifications** may still be handle-only until **`actorUserId`** exists in real payloads (M8a).
- **Mock Profile Saved folders** and **public “collections”** language may remain in non-remote/demo paths (M8c1).
- **Social counts** not placed on every surface (e.g. feed cards, connections app bar titles) (M8d).
- **English-only** custom strings until ARB work (M8e).

---

## Deferred Scope

- **share_plus / system share sheet** — optional dependency and UX; clipboard remains canonical path today (`docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md`).
- **ARB / `flutter gen-l10n` localization** — replace `NimonAppStrings` with generated `AppLocalizations` over time (`docs/M8E_SHARE_LOCALIZATION_POLISH_REPORT.md`).
- **Collections / folders** — product fork documented in M8c; no V1 schema/API commitment unless scope expands (`docs/M8C_COLLECTIONS_DECISION_SPEC.md`).
- **Legacy route full removal** — `creator=` query may remain for bookmarks/debug; full removal deferred pending entry-point audit and optional backend handle resolver (`docs/M8_DISCOVERY_AND_POLISH_PLAN.md` §3, M8a).
- **Further social count placement polish** — additional surfaces (cards, headers) if product wants parity beyond M8d.

---

## Final Verdict

**M8 (discovery and polish) is closed** relative to the planned slice list in `docs/M8_DISCOVERY_AND_POLISH_PLAN.md` §8: **M8a–M8e** are complete as documented in their child reports, with **collections implementation** explicitly **out of scope** for V1 and **share sheet / translated ARBs** explicitly **deferred** pending product and eng follow-up.

---

## Recommended Next Milestone

1. **Release / V1 hardening** — smoke passes, store readiness, and any **`NIMON_V1_RELEASE_PRIORITY_PLAN`**-style checklist if present in `docs/`.
2. **Product-approved optional upgrades** — add **`share_plus`** (or platform share) while preserving canonical URL; begin **ARB** migration from `NimonAppStrings`.
3. **If product reopens Saved organization** — implement **collections** per M8c §6+ (schema, APIs, Flutter) as a **separate** milestone with migrations and acceptance tests.
4. **Routing completion** — optional **`?creator=` → `?userId=`** resolution once every real entry point supplies **`writerId`** or a server resolver exists.

---

## Output Summary (checklist)

| Question | Answer |
|----------|--------|
| **M8 closed?** | **Yes** for the planned discovery/polish slices (M8a–M8e); collections **implementation** and full i18n are **out of scope / deferred**. |
| **Routing cleanup complete?** | **Yes** per M8a (canonical `userId`, legacy fenced). |
| **Followers complete?** | **Yes** per M8b (API + Flutter list). |
| **Saved-only decision complete?** | **Yes** per M8c + M8c1 (spec + Flutter polish). |
| **Share/localization complete?** | **Yes** for M8e scope (**centralized copy**, clipboard share); **system share** and **ARB** deferred. |
| **Tests passed?** | **Yes** at M8e closeout — full **`flutter test`** green (**344** tests in M8e report). |
| **Deferred scope** | **share_plus**, **ARB/gen-l10n**, **collections/folders**, **full legacy route removal**, **extra count placement**. |
| **Next milestone recommendation** | **V1 release hardening**; then product-approved **share_plus** + **ARB**; **collections** only if product reopens; optional **routing resolver** for handle links. |
