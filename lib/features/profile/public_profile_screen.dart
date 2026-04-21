import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/public_profile_data.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Learner-facing public profile (V1). Owner management stays on [ProfileScreen].
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    this.ownerPreview = false,
    this.creatorHandle,
  });

  /// When true, show a minimal banner (e.g. opened from "View public profile").
  final bool ownerPreview;
  final String? creatorHandle;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late final PublicProfileBundle _data;
  bool _isFollowing = false;

  /// Outer [NestedScrollView] scroll — used to know when the tab bar is pinned.
  final ScrollController _publicProfileScrollController = ScrollController();

  /// Bounds the profile header + CTA + divider for scroll math.
  final GlobalKey _profileHeaderSectionKey = GlobalKey();

  /// Height of [_profileHeaderSectionKey] once measured.
  double? _headerSectionHeight;

  /// When true, the pinned tab bar sits under the status bar and needs top inset.
  bool _tabsNeedTopSafeArea = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _data = _bundleForCreator(widget.creatorHandle);
    _publicProfileScrollController.addListener(_onPublicProfileOuterScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHeaderSection();
      _onPublicProfileOuterScroll();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHeaderSection();
      _onPublicProfileOuterScroll();
    });
  }

  void _measureHeaderSection() {
    final ctx = _profileHeaderSectionKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final h = box.size.height;
    if (h != _headerSectionHeight) {
      setState(() => _headerSectionHeight = h);
    }
  }

  void _onPublicProfileOuterScroll() {
    if (!_publicProfileScrollController.hasClients) return;
    final h = _headerSectionHeight;
    if (h == null) return;
    final o = _publicProfileScrollController.offset;
    // When the outer scroll reaches the end of the header block, the tab sliver pins.
    final pinned = o >= (h - 2).clamp(0.0, double.infinity);
    if (pinned != _tabsNeedTopSafeArea) {
      setState(() => _tabsNeedTopSafeArea = pinned);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publicProfileScrollController.removeListener(_onPublicProfileOuterScroll);
    _publicProfileScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _openFolder(String folderId) {
    context.push('/profile/public/folder/$folderId');
  }

  void _showPublicCollectionMenu(PublicFolder folder) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share collection'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share — coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _storyPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open “$title” — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: scheme.surface,
        body: NestedScrollView(
        controller: _publicProfileScrollController,
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (SizeChangedLayoutNotification notification) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _measureHeaderSection();
                  _onPublicProfileOuterScroll();
                });
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: Column(
                  key: _profileHeaderSectionKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _PublicProfileHeader(
                  bundle: _data,
                  topPadding: topPad,
                  onBack: () => context.pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: widget.ownerPreview
                      ? Material(
                          color: scheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 20,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This is how other learners view your page.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: _isFollowing
                                    ? OutlinedButton.icon(
                                        onPressed: () => setState(
                                          () => _isFollowing = false,
                                        ),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Following'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 50),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: scheme.onSurface,
                                          side: BorderSide(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.75),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          textStyle: theme
                                              .textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : FilledButton.icon(
                                        onPressed: () => setState(
                                          () => _isFollowing = true,
                                        ),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Follow'),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 50),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          backgroundColor: scheme.primary,
                                          foregroundColor: scheme.onPrimary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          textStyle: theme
                                              .textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Share — coming soon'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('Share'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 50),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: scheme.onSurface,
                                    side: BorderSide(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.75),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle:
                                        theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PublicProfileTabsHeaderDelegate(
              scheme: scheme,
              textTheme: theme.textTheme,
              topInset: topPad,
              applyTopSafeArea: _tabsNeedTopSafeArea,
              tabTopPadding: 8,
              tabBar: TabBar(
                controller: _tabController,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.primary,
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
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PublicMonoTab(
              stories: _data.stories,
              onOpenStory: _storyPlaceholder,
            ),
            _PublicCollectionsTab(
              folders: _data.folders,
              onOpenFolder: _openFolder,
              onCollectionMenu: _showPublicCollectionMenu,
            ),
          ],
        ),
      ),
    );
  }
}

PublicProfileBundle _bundleForCreator(String? handle) {
  final h = (handle ?? '').trim();
  if (h.isEmpty || h == nimonDemoPublicProfile.handle) {
    return nimonDemoPublicProfile;
  }
  final display = switch (h) {
    '@rina_travel' => 'Rina / 旅と言葉',
    '@kumo_mono' => 'Studio Kumo',
    '@hikari_reads' => 'Hikari Reads',
    '@mono_friends' => 'Mono Friends',
    '@ao_story' => '蒼',
    '@misaki_note' => '美咲',
    _ => h.startsWith('@') ? h.substring(1) : h,
  };
  final seed = h.replaceAll('@', '').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  final cover = 'https://picsum.photos/seed/${seed}cover/1200/400';
  final avatar = 'https://picsum.photos/seed/${seed}avatar/200/200';
  return PublicProfileBundle(
    displayName: display,
    handle: h,
    bio: 'Mono creator • Japanese micro-stories',
    coverImageUrl: cover,
    avatarUrl: avatar,
    storiesCount: 6,
    followersCount: 42,
    followingCount: 18,
    featuredStoryId: null,
    stories: nimonDemoPublicProfile.stories,
    folders: nimonDemoPublicProfile.folders,
  );
}

class _PublicProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PublicProfileTabsHeaderDelegate({
    required this.scheme,
    required this.textTheme,
    required this.topInset,
    required this.applyTopSafeArea,
    required this.tabTopPadding,
    required this.tabBar,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final double topInset;

  /// Status-bar / notch inset applied only while the tab bar is pinned at the top.
  final bool applyTopSafeArea;

  final double tabTopPadding;
  final TabBar tabBar;

  double get _topPad => applyTopSafeArea ? topInset : 0;

  @override
  double get minExtent =>
      tabBar.preferredSize.height + _topPad + tabTopPadding;

  @override
  double get maxExtent =>
      tabBar.preferredSize.height + _topPad + tabTopPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tabH = tabBar.preferredSize.height + tabTopPadding + _topPad;

    return SizedBox(
      height: tabH,
      child: Material(
        color: scheme.surface,
        elevation: overlapsContent ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.only(
            top: _topPad + tabTopPadding,
          ),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PublicProfileTabsHeaderDelegate oldDelegate) {
    return scheme != oldDelegate.scheme ||
        tabBar != oldDelegate.tabBar ||
        tabTopPadding != oldDelegate.tabTopPadding ||
        applyTopSafeArea != oldDelegate.applyTopSafeArea ||
        topInset != oldDelegate.topInset;
  }
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({
    required this.bundle,
    required this.topPadding,
    required this.onBack,
  });

  final PublicProfileBundle bundle;
  final double topPadding;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final coverUrl = bundle.coverImageUrl;
    final avatarUrl = bundle.avatarUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              child: SizedBox(
                height: 172,
                width: double.infinity,
                child: _CoverImage(url: coverUrl),
              ),
            ),
            Positioned(
              top: topPadding + 6,
              left: 6,
              child: NimonCircleNavButton(
                onPressed: onBack,
                tooltip: 'Back',
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: -40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Avatar(url: avatarUrl, radius: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          _StatChip(
                            value: '${bundle.storiesCount}',
                            label: 'Stories',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            value: '${bundle.followersCount}',
                            label: 'Followers',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            value: '${bundle.followingCount}',
                            label: 'Following',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                bundle.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bundle.handle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((bundle.bio ?? '').trim().isNotEmpty) ...[
                Text(
                  bundle.bio!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = (url ?? '').trim().isNotEmpty;
    if (has) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _CoverFallback(scheme: scheme),
      );
    }
    return _CoverFallback(scheme: scheme);
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.tertiaryContainer.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_outlined,
          size: 48,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = (url ?? '').trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        backgroundImage: has ? NetworkImage(url!) : null,
        onBackgroundImageError: has ? (_, __) {} : null,
        child: has
            ? null
            : Icon(
                Icons.person_rounded,
                size: radius * 1.1,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicMonoTab extends StatelessWidget {
  const _PublicMonoTab({
    required this.stories,
    required this.onOpenStory,
  });

  final List<PublicStory> stories;
  final void Function(String title) onOpenStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (stories.isEmpty) {
      return Center(
        child: Text(
          'No public stories yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('public_mono'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: stories.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: scheme.outlineVariant.withValues(alpha: 0.28),
      ),
      itemBuilder: (context, i) {
        final s = stories[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenStory(s.title),
            child: MonoStoryListRow(
              title: s.title,
              description: s.description,
              jlptLevel: s.jlptLevel,
              thumbnailUrl: s.thumbnailUrl,
              onMenuTap: null,
            ),
          ),
        );
      },
    );
  }
}

class _PublicCollectionsTab extends StatelessWidget {
  const _PublicCollectionsTab({
    required this.folders,
    required this.onOpenFolder,
    required this.onCollectionMenu,
  });

  final List<PublicFolder> folders;
  final void Function(String folderId) onOpenFolder;
  final void Function(PublicFolder folder) onCollectionMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (folders.isEmpty) {
      return Center(
        child: Text(
          'No public collections yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('public_collections'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: folders.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: scheme.outlineVariant.withValues(alpha: 0.28),
      ),
      itemBuilder: (context, i) {
        final f = folders[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenFolder(f.id),
            child: PublicCollectionListRow(
              folder: f,
              onMenuTap: () => onCollectionMenu(f),
            ),
          ),
        );
      },
    );
  }
}
