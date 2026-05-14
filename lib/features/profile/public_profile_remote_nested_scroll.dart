import 'package:flutter/material.dart';

import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Pinned TabBar strip for remote public profile (M14J-A5 / M14J-A6).
/// Kept outside [SliverAppBar.bottom] so it sits directly under the profile
/// info panel without a tall empty flex slot above the tabs.
class PublicProfileTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  PublicProfileTabBarHeaderDelegate({
    required this.backgroundColor,
    required this.tabController,
    required this.theme,
    required this.scheme,
    required this.onTap,
  }) : _extent = _kTabBarHeight;

  /// Material 3 [TabBar] strip height (no extra vertical chrome).
  static const double _kTabBarHeight = 48;

  final Color backgroundColor;
  final TabController tabController;
  final ThemeData theme;
  final ColorScheme scheme;
  final ValueChanged<int> onTap;

  final double _extent;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tabBar = TabBar(
      key: const ValueKey('publicProfileTabBar'),
      controller: tabController,
      onTap: onTap,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.onSurface,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      tabs: const [
        Tab(text: 'Monos'),
        Tab(text: 'Collections'),
      ],
    );

    return SizedBox(
      height: _extent,
      child: Material(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PublicProfileTabBarHeaderDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        tabController != oldDelegate.tabController ||
        theme != oldDelegate.theme ||
        scheme != oldDelegate.scheme;
  }
}

/// Instagram-style [NestedScrollView] for remote public creator profile (M14J-A).
///
/// M14J-A6: [SliverAppBar] [flexibleSpace] is **cover only**; profile identity
/// and actions live in a following [SliverToBoxAdapter] so there is no oversized
/// flexible region above the pinned [TabBar].
///
/// M17B: [FlexibleSpaceBar] uses [CollapseMode.none] and no stretch modes so the
/// cover does not add extra motion. [SliverOverlapAbsorber] overlap with the
/// profile [SliverToBoxAdapter] is offset in [PublicProfileScreen] using the
/// pinned toolbar obstruction height (status-bar padding + toolbar height).
class PublicProfileRemoteNestedScroll extends StatelessWidget {
  const PublicProfileRemoteNestedScroll({
    super.key,
    this.scrollController,
    required this.tabController,
    required this.theme,
    required this.scheme,
    required this.coverExpandedHeight,
    required this.displayName,
    required this.coverFlexibleBackground,
    required this.profileInfoPanel,
    required this.monoTabBuilder,
    required this.collectionsTabBuilder,
    required this.onTabBarTap,
  });

  /// Toolbar + cover image slot (status bar is added by [SliverAppBar] itself).
  static const double kRemotePublicToolbarHeight = 56;

  /// Remote public profile cover slot (flexible region below toolbar only).
  /// M14J-A10: shorter cover; hero overlay sits fully inside this slot.
  static const double kRemotePublicCoverImageHeight = 146;
  static const double kRemotePublicCoverExpandedTotal =
      kRemotePublicToolbarHeight + kRemotePublicCoverImageHeight;

  final ScrollController? scrollController;
  final TabController tabController;
  final ThemeData theme;
  final ColorScheme scheme;

  /// [SliverAppBar.expandedHeight] — cover region only (M14J-A6).
  final double coverExpandedHeight;
  final String displayName;
  final Widget coverFlexibleBackground;
  final Widget profileInfoPanel;
  final Widget Function(BuildContext nestedContext) monoTabBuilder;
  final Widget Function(BuildContext nestedContext) collectionsTabBuilder;
  final ValueChanged<int> onTabBarTap;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      key: const ValueKey('publicProfileNestedScrollView'),
      controller: scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar(
              pinned: true,
              // NestedScrollView + SliverAppBar.stretch is unsupported per Flutter
              // docs; keep cover collapse stable without overscroll stretch quirks.
              stretch: false,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: coverExpandedHeight,
              leading: const NimonBackButton(tooltip: 'Back'),
              title: AnimatedOpacity(
                opacity: innerBoxIsScrolled ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Text(
                  displayName,
                  key: const ValueKey('publicProfileToolbarUsername'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                stretchModes: const <StretchMode>[],
                background: coverFlexibleBackground,
              ),
            ),
          ),
          SliverToBoxAdapter(
            key: const ValueKey('publicProfileProfileInfoSliver'),
            child: profileInfoPanel,
          ),
          SliverPersistentHeader(
            key: const ValueKey('publicProfilePinnedTabBarHeader'),
            pinned: true,
            delegate: PublicProfileTabBarHeaderDelegate(
              backgroundColor: scheme.surface,
              tabController: tabController,
              theme: theme,
              scheme: scheme,
              onTap: onTabBarTap,
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: tabController,
        children: [
          Builder(builder: monoTabBuilder),
          Builder(builder: collectionsTabBuilder),
        ],
      ),
    );
  }
}
