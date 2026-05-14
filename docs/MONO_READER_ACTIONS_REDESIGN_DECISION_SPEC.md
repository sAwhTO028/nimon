# Mono Reader Actions Redesign Decision Spec

## Problem

The Mono reader currently presents multiple “side rail” actions (React, Learn, Bookmark, Share). While functional, the rail competes with the reading experience and makes the reader feel busy and less premium—especially in read mode where the rail occupies a dedicated right-column footprint.

We want a cleaner, more premium reader that keeps the primary quick action (React) immediately accessible while moving secondary actions into a single “More” surface. Learn is special: it represents Nimon’s core reading + learning value and should not become “buried” in a menu.

## Goals

- Make the reader feel **cleaner** and more **premium** by reducing always-visible chrome.
- Keep **React** as a **one-tap** primary action.
- Consolidate secondary actions behind a single **More** entry point.
- Maintain **Learn discoverability** for Full Learn monos via an **inline CTA** inside the reader body.
- Preserve existing **bookmark rules** (especially own-content restrictions).
- Ensure Share uses the **standardized backend `shareUrl`** (never reintroduce `localhost` links on physical devices).
- Keep behavior consistent across light/dark themes with token-based styling.

## Non-goals

- No backend data model changes.
- No changes to learn module content generation/storage.
- No changes to quiz/listening/grammar behavior.
- No changes to mono feed pagination/prefetch.
- No full reader layout redesign (typography, page model, navigation architecture).

## Current UX

Today the reader exposes a fixed “rail” with four action slots:

- **React** (heart) + like count label
- **Learn**
- **Save / Saved** (bookmark; hidden/disabled by policy in some cases)
- **Share**

In read mode, the rail is shown in a bottom-right region (collapsible) and uses token-based colors (e.g. active react uses `react`, saved uses `actionPrimary`, labels use `textSecondary`).

Observed drawbacks:

- Rail visually competes with the content (especially in an immersive reading mode).
- Learn can feel like “just another action” rather than a core value moment.
- Multiple labels/icons increase cognitive load and reduce the premium feel.

## Proposed UX

### Summary

- **Side rail**: show only **React** + **More (⋯)**.
- **More bottom sheet**: contains **Learn (conditional)**, **Save/Unsave (policy-aware)**, **Share**.
- **Inline Full Learn CTA**: for Full Learn monos only, show a soft CTA inside the reader body:
  - Title: **Ready to learn from this story?**
  - Button: **Start Learn**

### Why this works

- The rail becomes a minimal “quick action” surface.
- Secondary actions are still accessible in one place.
- Learn remains discoverable through a content-adjacent CTA, not hidden behind an overflow menu.

## Side Rail Decision

**Decision:** The side rail shows only:

1. **React** (one-tap, with count label)
2. **More** (⋯) below React

**Removed from rail:** Learn, Save/Bookmark, Share.

Rationale:

- Reduces persistent chrome without removing features.
- Maintains the “one-tap dopamine loop” (React) which benefits from immediate access.
- Creates a consistent, premium “two-slot” rail across different mono types.

## More Bottom Sheet Decision

**Decision:** The More sheet includes:

- **Learn this story** — **only** when the mono has **Full Learn** content available.
- **Save / Unsave** — only when bookmark action is valid under current policy.
- **Share** — always shown when a canonical share URL is available; if unavailable, show disabled row or an explanatory message.

**Do not show Learn** when Full Learn content is unavailable.

Learn availability rule (V1 contract):

- Show Learn in the sheet when `PublishedMonoAccess.isFullLearnPublished == true`.
- If product requires “real learn modules” (not just the badge), additionally require `PublishedMonoAccess.learnModulesInPayload == true`.
  - This is an explicit decision point during implementation; the UX spec supports either behavior.

## Full Learn CTA Decision

**Decision:** For Full Learn monos, show an inline CTA inside the reader body content.

Copy (initial):

- **Title:** Ready to learn from this story?
- **Button:** Start Learn

Behavior:

- CTA appears only for Full Learn monos.
- CTA routes to the same Learn destination as the existing Learn action.
- CTA should be subtle and premium (token-based colors, soft surface, minimal elevation).

Placement guidance:

- Prefer placement after an initial “reading commitment” moment (e.g., after the first paragraph / first page block), not at the very top.
- Avoid interrupting very short content; for very short monos, allow CTA near the end as a follow-on.

## Learn Discoverability Rationale

Hiding Learn inside “More” risks reducing engagement with Nimon’s differentiator.

The inline CTA solves that by:

- Making Learn discoverable **in context** of reading.
- Preserving a cleaner rail.
- Positioning Learn as an “upgrade of intent” (from reading → learning), not an incidental icon.

## Bookmark Policy

**Decision:** Preserve current bookmark/own-content rules.

- If policy disallows bookmarking the current mono (e.g., own content), the More sheet must **not** show Save/Unsave actions that the user cannot take.
- If current policy allows bookmark toggling but requires auth, More sheet should continue to show the action but follow existing guest UX (snackbar: sign in required).

## Share Policy

**Decision:** Share uses the backend-provided canonical `shareUrl` when present.

- Do not construct `http://localhost:3000/mono/...` on the client.
- If a fallback exists, it must use a configured public web base (e.g. `NIMON_PUBLIC_WEB_BASE_URL`) or a non-loopback API base in dev, and must refuse loopback origins on physical devices.

## React Policy

**Decision:** React remains the primary one-tap action on the rail.

- Active heart keeps the current muted react color token behavior.
- Inactive heart uses token-based ink (`textPrimary` or `textSecondary` per current rail spec).
- Like count remains visible in the rail label (or a minimal count indicator adjacent to the icon—implementation choice).

## Visual Style

- Rail and sheet must remain **token-based**: `surface`, `appBackground`, `textPrimary`, `textSecondary`, `border`, `actionPrimary`, `react`.
- More sheet should feel premium:
  - clear hierarchy
  - consistent spacing
  - readable in dark mode (no hardcoded whites/greys)
- Inline CTA should match premium tone:
  - soft surface container
  - low/no shadow
  - clear primary button using `actionPrimary` + `onPrimary`

## Accessibility

- Rail icons must have semantic labels (React count included, “More actions”).
- More sheet rows must have:
  - minimum 44px tap targets
  - clear disabled states with explanation where relevant
- Inline CTA:
  - button focus/semantics label (“Start Learn”)
  - sufficient contrast in both themes

## Edge Cases

- **Read-only publish:** Learn must not appear in sheet or inline CTA.
- **Full Learn publish but learn data not available** (`learnModulesInPayload == false`):
  - Decide whether to show Learn as disabled with explanation, or hide it entirely.
- **Guest user:** Save/React actions follow existing “sign in required” UX without adding new auth flows.
- **Own content:** Save hidden/disabled per existing rule.
- **Missing `shareUrl`:** share row disabled or replaced with message (“Share link unavailable”).
- **Very short monos:** CTA placement should avoid feeling like “ads”; place at end or omit if it harms flow.

## Implementation Split

Milestone split for small, reviewable increments:

- **M12a**: Decision spec only (this doc)
- **M12b**: Side rail + More bottom sheet
- **M12c**: Inline Full Learn CTA
- **M12d**: Tests + closeout

## Manual Smoke Checklist

- React is still one tap
- More opens bottom sheet
- Full Learn mono shows Learn in sheet
- Non-Full Learn mono does not show Learn in sheet
- Full Learn mono shows inline Start Learn CTA
- Start Learn opens correct Learn page
- Bookmark respects own-content policy
- Share uses standardized shareUrl
- Dark/light mode sheet is readable

## Risks

- Learn engagement could drop if the inline CTA is too subtle or placed poorly.
- If Learn gating differs between “Full Learn badge” vs “learn modules present,” the UX could feel inconsistent across monos; must align on a single rule.
- More sheet could become overloaded over time; future actions should be carefully curated (avoid becoming a “junk drawer”).
- Any change to rail structure risks regression in gesture hit targets and read-mode layout; requires careful device testing.

## Recommended Next Step

Implement **M12b** (side rail + More sheet) first, then **M12c** (inline CTA), then **M12d** for coverage and regression-proofing.

