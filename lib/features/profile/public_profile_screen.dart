import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/l10n/nimon_app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/public_profile_data.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/public_profile_routing_policy.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';
import 'package:nimon/features/profile/public_creator_collection_detail_screen.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart'
    show remoteUserFollowRepositoryProvider, followingMonoFeedPagerProvider;
import 'package:nimon/features/profile/presentation/providers/profile_following_pager.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Learner-facing public profile (V1). Owner management stays on [ProfileScreen].
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({
    super.key,
    this.ownerPreview = false,
    this.userId,
    this.creatorHandle,
  });

  /// When true, show a minimal banner (e.g. opened from "View public profile").
  final bool ownerPreview;

  /// Canonical route param (M7e3b): public profile keyed by backend `users.id`.
  final String? userId;

  /// Legacy query `?creator=` — **debug-only** mock profile (see [legacyDemoCreatorProfileActive]).
  /// Production builds ignore mock data for this param; use [userId].
  final String? creatorHandle;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late final PublicProfileBundle _data;
  PublicCreatorProfile? _remoteProfile;
  Object? _remoteError;
  bool _loadingProfile = false;

  final List<MonoFeedItem> _creatorMonos = <MonoFeedItem>[];
  String? _creatorNextCursor;
  bool _creatorHasMore = false;
  bool _loadingCreatorMonos = false;
  Object? _creatorMonosError;

  /// Remote public profile: 0 = all published monos, 1 = creator collections (M8f4).
  int _remoteProfileMainTab = 0;
  final List<CreatorMonoCollection> _publicCollections =
      <CreatorMonoCollection>[];
  bool _loadingPublicCollections = false;
  Object? _publicCollectionsError;

  bool? _followOptimistic;
  int? _followersCountOptimistic;

  // Legacy mock-only follow state for handle-routed profiles.
  bool _isFollowingLegacy = false;

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
    _data = _bundleForCreator(
      legacyDemoCreatorProfileActive(
        userId: widget.userId,
        creatorHandle: widget.creatorHandle,
      )
          ? widget.creatorHandle
          : null,
    );
    _publicProfileScrollController.addListener(_onPublicProfileOuterScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHeaderSection();
      _onPublicProfileOuterScroll();
      unawaited(_loadRemoteIfNeeded());
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

  String get _routeUserId => (widget.userId ?? '').trim();

  bool get _useRemoteProfile => _routeUserId.isNotEmpty;

  bool get _isAuthed =>
      ref.read(authSessionProvider) is AuthSessionAuthenticated;

  String? get _authedUserId {
    final s = ref.read(authSessionProvider);
    return s is AuthSessionAuthenticated ? s.user.id : null;
  }

  bool get _isSelfProfile {
    final me = _authedUserId?.trim() ?? '';
    if (me.isEmpty) return false;
    return me == _routeUserId;
  }

  bool get _isFollowingEffective {
    if (_followOptimistic != null) return _followOptimistic!;
    return _remoteProfile?.isFollowingByMe ?? false;
  }

  int get _followersCountEffective {
    if (_followersCountOptimistic != null) return _followersCountOptimistic!;
    return _remoteProfile?.followersCount ?? 0;
  }

  Future<void> _loadRemoteIfNeeded() async {
    if (!_useRemoteProfile) return;
    if (_loadingProfile) return;
    setState(() {
      _loadingProfile = true;
      _remoteError = null;
    });
    try {
      final repo = ref.read(remotePublicCreatorProfileRepositoryProvider);
      final p = await repo.fetchPublicCreatorProfile(_routeUserId);
      if (!mounted) return;
      setState(() {
        _remoteProfile = p;
        _loadingProfile = false;
      });
      await _loadCreatorMonosFirstPage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _remoteError = e;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadCreatorMonosFirstPage() async {
    if (!_useRemoteProfile) return;
    if (_loadingCreatorMonos) return;
    setState(() {
      _loadingCreatorMonos = true;
      _creatorMonosError = null;
      _creatorMonos.clear();
      _creatorNextCursor = null;
      _creatorHasMore = false;
    });
    try {
      final repo = ref.read(remotePublicCreatorProfileRepositoryProvider);
      final page = await repo.fetchCreatorMonoPage(_routeUserId, limit: 15);
      if (!mounted) return;
      setState(() {
        _creatorMonos
          ..clear()
          ..addAll(page.items.map(monoFeedItemFromMonoFeedSummary));
        _creatorNextCursor = page.nextCursor;
        _creatorHasMore = page.hasMore;
        _loadingCreatorMonos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatorMonosError = e;
        _loadingCreatorMonos = false;
      });
    }
  }

  Future<void> _loadCreatorMonosMore() async {
    if (!_useRemoteProfile) return;
    if (_loadingCreatorMonos) return;
    if (!_creatorHasMore) return;
    final cursor = _creatorNextCursor;
    if (cursor == null || cursor.trim().isEmpty) return;
    setState(() {
      _loadingCreatorMonos = true;
      _creatorMonosError = null;
    });
    try {
      final repo = ref.read(remotePublicCreatorProfileRepositoryProvider);
      final page = await repo.fetchCreatorMonoPage(
        _routeUserId,
        cursor: cursor,
        limit: 15,
      );
      if (!mounted) return;
      setState(() {
        _creatorMonos.addAll(page.items.map(monoFeedItemFromMonoFeedSummary));
        _creatorNextCursor = page.nextCursor;
        _creatorHasMore = page.hasMore;
        _loadingCreatorMonos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatorMonosError = e;
        _loadingCreatorMonos = false;
      });
    }
  }

  Future<void> _loadPublicCollections() async {
    if (!_useRemoteProfile) return;
    if (_loadingPublicCollections) return;
    setState(() {
      _loadingPublicCollections = true;
      _publicCollectionsError = null;
      _publicCollections.clear();
    });
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      final list = await repo.fetchPublicCollections(_routeUserId);
      if (!mounted) return;
      setState(() {
        _publicCollections
          ..clear()
          ..addAll(list);
        _loadingPublicCollections = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publicCollectionsError = e;
        _loadingPublicCollections = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareCreatorProfileLink() async {
    if (!_useRemoteProfile) return;
    final url =
        'https://nimon.app/profile/public?userId=${Uri.encodeComponent(_routeUserId)}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _snack(NimonAppStrings.shareLinkCopied);
  }

  String _remoteMonosStatLabel() {
    if (_loadingCreatorMonos && _creatorMonos.isEmpty) {
      return '…';
    }
    final n = _creatorMonos.length;
    if (n == 0) {
      return formatSocialCount(0);
    }
    if (_creatorHasMore) {
      return '${formatSocialCount(n)}+';
    }
    return formatSocialCount(n);
  }

  Future<void> _toggleFollow() async {
    if (!_useRemoteProfile) return;
    if (!_isAuthed) {
      _snack(NimonAppStrings.signInToFollowCreators);
      return;
    }
    if (_isSelfProfile) return;
    final before = _isFollowingEffective;
    final beforeCount = _followersCountEffective;
    final next = !before;
    setState(() {
      _followOptimistic = next;
      _followersCountOptimistic =
          (beforeCount + (next ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      final repo = ref.read(remoteUserFollowRepositoryProvider);
      final out = next
          ? await repo.followUser(_routeUserId)
          : await repo.unfollowUser(_routeUserId);
      if (!mounted) return;
      setState(() {
        _followOptimistic = out.isFollowing;
        _followersCountOptimistic = out.followersCount;
      });
      // Refresh following feed/list surfaces.
      unawaited(ref.read(followingMonoFeedPagerProvider.notifier).refresh());
      unawaited(
          ref.read(profileFollowingPagerProvider.notifier).loadFirstPage());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _followOptimistic = before;
        _followersCountOptimistic = beforeCount;
      });
      _snack(e is StateError ? e.message : 'Could not update follow.');
    }
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

    if (_useRemoteProfile) {
      if (_loadingProfile && _remoteProfile == null) {
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
              leading: const NimonBackButton(), title: const Text('Creator')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (_remoteError != null && _remoteProfile == null) {
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
              leading: const NimonBackButton(), title: const Text('Creator')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load creator profile.'),
                  const SizedBox(height: 8),
                  Text('$_remoteError', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadRemoteIfNeeded,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final rp = _remoteProfile;
      if (rp != null) {
        final displayName = rp.effectiveDisplayName;
        final handle = (rp.handle ?? '').trim();
        final bio = (rp.bio ?? '').trim();

        Widget monoSection() {
          if (_loadingCreatorMonos && _creatorMonos.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_creatorMonosError != null && _creatorMonos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Could not load stories: $_creatorMonosError'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadCreatorMonosFirstPage,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (_creatorMonos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No published monos yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _creatorMonos.length; i++)
                Padding(
                  key:
                      ValueKey<String>('public_mono_${_creatorMonos[i].id}_$i'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push(
                          '/mono-reader',
                          extra: <String, Object>{
                            'items': List<MonoFeedItem>.from(_creatorMonos),
                            'initialIndex': i,
                            'readerMenuOrigin':
                                MonoReaderMenuOrigin.publicCreatorProfile,
                          },
                        );
                      },
                      child: MonoStoryListRow(
                        title: (_creatorMonos[i].title ?? '').trim().isEmpty
                            ? 'Untitled'
                            : _creatorMonos[i].title!.trim(),
                        description:
                            _creatorMonos[i].storyDescription.trim().isNotEmpty
                                ? _creatorMonos[i].storyDescription.trim()
                                : _creatorMonos[i].bodyText.trim(),
                        jlptLevel: _creatorMonos[i].level.trim(),
                        thumbnailUrl: _creatorMonos[i].coverImageUrl,
                      ),
                    ),
                  ),
                ),
              if (_creatorHasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: FilledButton(
                    onPressed:
                        _loadingCreatorMonos ? null : _loadCreatorMonosMore,
                    child: Text(
                      _loadingCreatorMonos ? 'Loading…' : 'Load more',
                    ),
                  ),
                ),
            ],
          );
        }

        Widget collectionsSection() {
          if (_loadingPublicCollections && _publicCollections.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_publicCollectionsError != null && _publicCollections.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Could not load collections: $_publicCollectionsError'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadPublicCollections,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (_publicCollections.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No collections yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final wName = displayName;
          final wHandle = handle.isNotEmpty ? handle : '@reader';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in _publicCollections)
                Padding(
                  key: ValueKey<String>('public_coll_${c.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RemotePublicCollectionCard(
                    collection: c,
                    onTap: () {
                      context.push(
                        '/profile/public/collections/detail',
                        extra: PublicCreatorCollectionDetailArgs(
                          userId: _routeUserId,
                          collection: c,
                          writerDisplayName: wName,
                          writerHandle: wHandle,
                          writerAvatarUrl:
                              (rp.avatarUrl ?? '').trim().isNotEmpty
                                  ? rp.avatarUrl!.trim()
                                  : null,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: scheme.surface,
          body: RefreshIndicator(
            onRefresh: () async {
              await _loadRemoteIfNeeded();
              if (_remoteProfile != null) {
                await _loadCreatorMonosFirstPage();
                await _loadPublicCollections();
              }
            },
            child: CustomScrollView(
              controller: _publicProfileScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
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
                              child: _CoverImage(url: rp.coverImageUrl),
                            ),
                          ),
                          Positioned(
                            top: topPad + 6,
                            left: 6,
                            child: const NimonBackButton(
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
                                _Avatar(
                                  url: (rp.avatarUrl ?? '').trim().isNotEmpty
                                      ? rp.avatarUrl!.trim()
                                      : null,
                                  radius: 40,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        _StatChip(
                                          value: _remoteMonosStatLabel(),
                                          label: 'Monos',
                                        ),
                                        const SizedBox(width: 10),
                                        _StatChip(
                                          value: formatSocialCount(
                                            _followersCountEffective,
                                          ),
                                          label: 'Followers',
                                        ),
                                        const SizedBox(width: 10),
                                        _StatChip(
                                          value: formatSocialCount(
                                            rp.followingCount,
                                          ),
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
                              displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                            ),
                            if (handle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                handle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                bio,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.ownerPreview && _isSelfProfile)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Material(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.35),
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
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              if (!_isSelfProfile)
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: _isFollowingEffective
                                        ? OutlinedButton.icon(
                                            onPressed: _toggleFollow,
                                            icon: const Icon(
                                              Icons.check_rounded,
                                            ),
                                            label: const Text('Following'),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 50),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
                                            onPressed: _toggleFollow,
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text('Follow'),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 50),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              if (!_isSelfProfile) const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _shareCreatorProfileLink,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: SegmentedButton<int>(
                          key: const Key(
                              'public_profile_mono_collections_segments'),
                          segments: const [
                            ButtonSegment<int>(
                              value: 0,
                              label: Text('Monos'),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              label: Text('Collections'),
                            ),
                          ],
                          selected: {_remoteProfileMainTab},
                          onSelectionChanged: (Set<int> next) {
                            final v = next.first;
                            setState(() => _remoteProfileMainTab = v);
                            if (v == 1) {
                              unawaited(_loadPublicCollections());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _remoteProfileMainTab == 0
                        ? monoSection()
                        : collectionsSection(),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          leading: const NimonBackButton(),
          title: const Text('Creator'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (legacyDemoCreatorProfileActive(
      userId: widget.userId,
      creatorHandle: widget.creatorHandle,
    )) {
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Material(
                          color:
                              scheme.secondaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'DEV: Mock creator profile (?creator=). '
                              'Shipped builds use ?userId=.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _PublicProfileHeader(
                        bundle: _data,
                        topPadding: topPad,
                        onBack: () => context.pop(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: widget.ownerPreview
                            ? Material(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.35),
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
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
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
                                      child: _isFollowingLegacy
                                          ? OutlinedButton.icon(
                                              onPressed: () => setState(
                                                () =>
                                                    _isFollowingLegacy = false,
                                              ),
                                              icon: const Icon(
                                                  Icons.check_rounded),
                                              label: const Text('Following'),
                                              style: OutlinedButton.styleFrom(
                                                minimumSize: const Size(0, 50),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                foregroundColor:
                                                    scheme.onSurface,
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
                                                () => _isFollowingLegacy = true,
                                              ),
                                              icon:
                                                  const Icon(Icons.add_rounded),
                                              label: const Text('Follow'),
                                              style: FilledButton.styleFrom(
                                                minimumSize: const Size(0, 50),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                backgroundColor: scheme.primary,
                                                foregroundColor:
                                                    scheme.onPrimary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                textStyle: theme
                                                    .textTheme.labelLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Share — coming soon'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        icon:
                                            const Icon(Icons.ios_share_rounded),
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
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          textStyle: theme.textTheme.labelLarge
                                              ?.copyWith(
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

    if (creatorHandleOnlyRouteRejectedOutsideDebug(
      userId: widget.userId,
      creatorHandle: widget.creatorHandle,
    )) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          leading: const NimonBackButton(),
          title: const Text('Creator'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Open creator profiles from inside Nimon (links include userId). '
              'Handle-only preview exists only in debug builds.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: const NimonBackButton(),
        title: const Text('Creator'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Creator profiles open with a userId link. '
            'Use Mono or Your profile → View public profile.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
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
  double get minExtent => tabBar.preferredSize.height + _topPad + tabTopPadding;

  @override
  double get maxExtent => tabBar.preferredSize.height + _topPad + tabTopPadding;

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
                            value: formatSocialCount(bundle.storiesCount),
                            label: 'Stories',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            value: formatSocialCount(bundle.followersCount),
                            label: 'Followers',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            value: formatSocialCount(bundle.followingCount),
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

class _RemotePublicCollectionCard extends StatelessWidget {
  const _RemotePublicCollectionCard({
    required this.collection,
    required this.onTap,
  });

  final CreatorMonoCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        collection.title.trim().isEmpty ? 'Untitled' : collection.title.trim();
    final desc = (collection.description ?? '').trim();
    final countLabel =
        '${collection.itemCount} stor${collection.itemCount == 1 ? 'y' : 'ies'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: CollectionListRow(
          title: title,
          countLabel: countLabel,
          description: desc.isEmpty ? null : desc,
          coverImageUrl: collection.coverImageUrl,
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
