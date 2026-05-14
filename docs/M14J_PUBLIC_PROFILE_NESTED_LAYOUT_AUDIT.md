# M14J Public Profile Nested Layout — Pre-Implementation Audit

## Current root widget structure (remote `userId` profile)

When `_useRemoteProfile` is true and `_remoteProfile != null`:

- `Scaffold(backgroundColor: scheme.surface)`
- `body: RefreshIndicator`
  - `child: CustomScrollView(controller: _publicProfileScrollController, physics: AlwaysScrollableScrollPhysics)`
    - **SliverToBoxAdapter**: single large `Column` containing:
      - Cover `Stack` (fixed cover height 172, positioned **NimonBackButton** over cover, avatar + stat chips overlapping bottom)
      - Name / handle / bio `Padding`
      - Optional owner-preview banner **or** Follow / Share row
      - `Divider`
      - **`TabBar`** (M14I used `ValueKey('publicProfileMainTabBar')`; M14J-A uses `ValueKey('publicProfileTabBar')` on the remote `TabBar`, `controller: _tabController`)
    - **SliverPadding** + **SliverToBoxAdapter**: either `monoSection()` **or** `collectionsSection()` based on `_tabController.index` (not a `TabBarView`; one subtree rebuilt on tab change)

Loading / error branches use a separate `Scaffold` + `AppBar` + centered body (unchanged pattern).

## Current scroll owner

- **Single** `CustomScrollView` owns all vertical scroll: header column and tab content scroll together as one sliver list.
- `ScrollController` `_publicProfileScrollController` is attached to this `CustomScrollView` (also used by legacy mock `NestedScrollView` path).

## Current Monos / Collections selector

- Material **`TabBar`** with two tabs (`Monos`, `Collections`), same `_tabController` as today.
- Body selection: imperative `setState` via `_tabController.addListener(_onPublicProfileTabTick)` plus `onTap` on tab index `1` triggers `unawaited(_loadPublicCollections())`.

## Public profile provider usage (unchanged in M14J-A)

- `remotePublicCreatorProfileRepositoryProvider` — `fetchPublicCreatorProfile`, `fetchCreatorMonoPage` (pagination).
- `remoteCreatorCollectionsRepositoryProvider` — `fetchPublicCollections`.
- `remoteUserFollowRepositoryProvider`, `followingMonoFeedPagerProvider`, `profileFollowingPagerProvider` — follow side effects.
- `authSessionProvider` — `_isSelfProfile`, guards.

## Public monos “provider” / data path

- In-screen state: `_creatorMonos`, `_creatorNextCursor`, `_creatorHasMore`, `_loadingCreatorMonos`, `_creatorMonosError`.
- `_loadCreatorMonosFirstPage` / `_loadCreatorMonosMore` — same as before; **no API changes** in this pass.

## Public collections data path

- `_publicCollections`, `_loadingPublicCollections`, `_publicCollectionsError`, `_loadPublicCollections()` — unchanged.

## Risks

1. **NestedScrollView + TabBarView + inner CustomScrollView** must use `SliverOverlapAbsorber` / `SliverOverlapInjector` correctly or tabs will clip / jump.
2. **`expandedHeight`** vs long bio: too small clips flexible header; too large leaves excess parallax empty space. Mitigated with clamped height + bio-length bump.
3. **`innerBoxIsScrolled`** for toolbar title may lag slightly vs visual collapse of `FlexibleSpaceBar`; acceptable for V1; can refine with scroll notifications later.
4. **RefreshIndicator** must remain usable with short lists — `AlwaysScrollableScrollPhysics` on inner lists.
5. **Test keys** — `publicProfileTabBar`, `publicProfileNestedScrollView`, list keys for nested `TabBarView` bodies.
