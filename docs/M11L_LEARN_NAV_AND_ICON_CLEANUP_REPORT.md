# M11l Learn Navigation And Icon Cleanup Report

## Problems

1. **Quiz results — “Back to Learn”** used `context.go('/learn/:id')`, which **replaced** the navigator state and could leave the user off the original Learn hub stack (missing prior `extra`/context or landing on a stale shell route).
2. **Learn hub header** exposed a top-right **translate / explanation language** menu that product no longer wants in that position.
3. **Mono Reels (For You)** top bar showed an explicit **refresh** icon next to search; product wants only **search** visible while keeping other refresh paths.

## Quiz Result Navigation Fix

- Added **`lib/features/learn/learn_quiz_navigation.dart`** with  
  `navigateQuizResultBackToLearnHub(GoRouter router, String contentId)`.
- Logic: if already on `/learn/[id]`, return; if **cannot pop**, **`go('/learn/$id')`** (deep-link / thin stack fallback); otherwise **pop**, yield, **pop again** if still not on hub, then **`go`** if needed.
- Matches the typical stack after play: **Learn hub → quiz setup → result** (`play` was **replaced** by `result`, so two pops reach the hub).
- **`QuizResultScreen` “Back to Learn”** now calls this helper via `unawaited(...)` instead of `context.go(...)`.
- App bar **leading** still uses a single **`pop()`** (same as before) so the system/app back affordance steps back one screen at a time.

## Learn Header Icon Removal

- Removed **`PopupMenuButton`** with **`Icons.translate_outlined`** from **`LearnHubScreen`** header row.
- **Explanation language** is still driven by **`learnExplanationLanguageProvider`** (prefs + **Listening / Pronunciation** route encoding); only the hub header control was removed.

## Mono Reels Refresh Icon Removal

- Removed the **For You** **`Tooltip('Refresh feed')` + `Icons.refresh_rounded`** block from **`mono_screen.dart`**.
- **Unchanged:** `monoFeedPagerProvider.notifier.refresh()`, pull-to-refresh / internal retry / error **Retry** flows, **search** affordance, tabs, level menu.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/learn_quiz_navigation.dart` | **New** — pop-to-hub + fallback `go` |
| `lib/features/learn/quiz_result_screen.dart` | “Back to Learn” uses helper |
| `lib/features/learn/learn_hub_screen.dart` | Removed translate `PopupMenuButton` |
| `lib/features/mono/mono_screen.dart` | Removed top-bar refresh icon |

## Tests Added

| File | Purpose |
|------|---------|
| `test/features/learn/learn_quiz_result_navigation_widget_test.dart` | Typical stack: tap **Back to Learn** → hub; deep link: `go` fallback |
| `test/features/learn/learn_hub_screen_test.dart` | Extended: no translate icon / tooltip |
| `test/features/mono/mono_screen_refresh_icon_removed_test.dart` | Source guard: no refresh tooltip/icon; search kept |

## Commands Run

From repo root:

- `dart format` on touched files
- `flutter analyze` on touched paths (only **info**-level `withOpacity` deprecations in `learn_hub_screen.dart`; no new errors)
- `flutter test test/features/learn`
- `flutter test test/features/mono` (includes `mono_screen_refresh_icon_removed_test.dart` when run as directory)
- `flutter test` — **full suite passed**

## Manual Verification

1. Mono → Learn for a story → Quiz Practice → finish → **Back to Learn** → same Learn hub (`/learn/:id`), back stack sensible.
2. Learn header: **Learn** title + back; **no** translate icon.
3. Mono For You top bar: **search** only in that cluster; **no** refresh icon; pull-to-refresh / error Retry still behave as before.

## Remaining Risks

- If the quiz flow gains an **extra** route between hub and result without updating the helper, **two pops** might be insufficient; the final **`go('/learn/$id')`** still forces a coherent destination (metadata `extra` may be missing until a future pass restores args).
