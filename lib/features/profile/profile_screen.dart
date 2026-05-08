import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_processing_copy.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/creator_resume_draft.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/published_mono_id_sanitizer.dart';
import 'package:nimon/features/profile/data/published_mono_reader_mapper.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/features/profile/data/profile_public_providers.dart';
import 'package:nimon/features/profile/presentation/owner_profile_header_stats.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/features/profile/presentation/providers/profile_saved_mono_pager.dart';
import 'package:nimon/features/profile/presentation/providers/profile_workspace_draft_pager.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/mono/mono_screen.dart'
    show MonoContentType, MonoFeedItem;
import 'package:nimon/features/profile/profile_navigation_drawer.dart';
import 'package:nimon/features/profile/profile_push_drawer_scope.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';
import 'package:nimon/features/profile/owner_creator_collection_detail_screen.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/profile/presentation/add_to_collection_sheet.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';

class _OneShortItem {
  final String id;
  final String title;
  final String description;
  final String jlptLevel;
  final String? thumbnailUrl;
  final String? processingStatusLabel;

  /// Local [CreatorStoryV1] id from backend, when the published mono is linked to a draft.
  /// Used to hide a Published row when that draft is in Workspace "Editing" (and for resume).
  final String? sourceDraftId;

  /// List row is backed by [RemotePublishedMonoRepository] (real PublishedMono list).
  final bool isBackendPublished;
  final String? categoryText;
  final String? targetDurationText;
  final String? publishBadgeText;

  const _OneShortItem({
    required this.id,
    required this.title,
    required this.description,
    required this.jlptLevel,
    this.thumbnailUrl,
    this.processingStatusLabel,
    this.sourceDraftId,
    this.isBackendPublished = false,
    this.categoryText,
    this.targetDurationText,
    this.publishBadgeText,
  });
}

enum _OneShortCardAction { edit, bookmark }

enum _ProfileFolderFilter { monos, collections }

/// Shared Add / Rename collection surface. [useRootNavigator] places the sheet above
/// the shell [FloatingDockNavBar] so the scrim fully covers the dock.
Future<String?> _showCollectionNameBottomSheet(
  BuildContext context, {
  required String headline,
  required String initialName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CollectionNameSheet(
      headline: headline,
      initialName: initialName,
    ),
  );
}

class _CollectionNameSheet extends StatefulWidget {
  const _CollectionNameSheet({
    required this.headline,
    required this.initialName,
  });

  final String headline;
  final String initialName;

  @override
  State<_CollectionNameSheet> createState() => _CollectionNameSheetState();
}

class _CollectionNameSheetState extends State<_CollectionNameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop<String>(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomSafe),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.headline,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Collection name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop<String>(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryFolder {
  final String id;
  final String name;
  final List<_OneShortItem> items;
  final bool isPrivate;

  const _StoryFolder({
    required this.id,
    required this.name,
    required this.items,
    this.isPrivate = false,
  });
}

String? _firstStoryThumbnailUrl(List<_OneShortItem> items) {
  for (final it in items) {
    final u = (it.thumbnailUrl ?? '').trim();
    if (u.isNotEmpty) return u;
  }
  return null;
}

class ProfileScreen extends ConsumerStatefulWidget {
  final StoryRepo repo;

  /// Profile content tabs: 0 = Published, 1 = Workspace, 2 = Saved. Null uses 0.
  final int? initialTabIndex;

  /// When opening Workspace (e.g. after publish), scroll to and pulse this draft card.
  final String? highlightDraftId;

  const ProfileScreen({
    super.key,
    required this.repo,
    this.initialTabIndex,
    this.highlightDraftId,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  static const _uploadedMock = <_OneShortItem>[
    _OneShortItem(
      id: 'os_u_1',
      title: '雨上がりの駅で',
      description: '改札前で起きた小さな出会いと、言えなかった一言。',
      jlptLevel: 'N4',
      thumbnailUrl: 'https://picsum.photos/seed/u1/300/300',
    ),
    _OneShortItem(
      id: 'os_u_2',
      title: '引き出しの古い鍵',
      description: '使われなくなった鍵が、忘れていた約束を思い出させる。',
      jlptLevel: 'N3',
      thumbnailUrl: 'https://picsum.photos/seed/u2/300/300',
    ),
    _OneShortItem(
      id: 'os_u_3',
      title: '新しい職場の初日',
      description: '緊張と失敗の連続、それでも少しだけ前に進めた日。',
      jlptLevel: 'N4',
    ),
    _OneShortItem(
      id: 'os_u_4',
      title: '夜の図書館',
      description: '閉館前の静けさの中で、読みかけのページが揺れた。',
      jlptLevel: 'N2',
    ),
  ];

  static const _processingMock = <_OneShortItem>[
    _OneShortItem(
      id: 'os_p_1',
      title: '引っ越しの手紙',
      description: '新しい町の匂いと、遠くなった友だちへの近況。',
      jlptLevel: 'N3',
    ),
    _OneShortItem(
      id: 'os_p_2',
      title: '教室の発表前',
      description: '前に立つ直前、机の下で握ったメモの感触。',
      jlptLevel: 'N5',
    ),
  ];

  static const _bookmarkMock = <_OneShortItem>[
    _OneShortItem(
      id: 'os_b_1',
      title: '町の図書館',
      description: '静かな閲覧室と、返却期限のしおり。',
      jlptLevel: 'N4',
      thumbnailUrl: 'https://picsum.photos/seed/b1/300/300',
    ),
    _OneShortItem(
      id: 'os_b_2',
      title: '来客対応',
      description: '応接室での名刺交換と、丁寧な言い回し。',
      jlptLevel: 'N3',
    ),
    _OneShortItem(
      id: 'os_b_3',
      title: '地方と移住',
      description: '人口減少と、空き家をめぐる取り組み。',
      jlptLevel: 'N2',
    ),
  ];

  static final _uploadedFoldersMock = <_StoryFolder>[
    _StoryFolder(
      id: 'uf_1',
      name: 'Daily uploads',
      isPrivate: true,
      items: [
        _uploadedMock[0],
        _uploadedMock[2],
      ],
    ),
    _StoryFolder(
      id: 'uf_2',
      name: 'Longer reads',
      items: [
        _uploadedMock[1],
        _uploadedMock[3],
      ],
    ),
  ];

  static final _savedFoldersMock = <_StoryFolder>[
    _StoryFolder(
      id: 'sf_1',
      name: 'Favorites',
      items: [
        _bookmarkMock[0],
        _bookmarkMock[1],
      ],
    ),
    _StoryFolder(
      id: 'sf_2',
      name: 'Later',
      items: [
        _bookmarkMock[2],
      ],
    ),
  ];

  // Direct (non-folder) content examples for the new filter-based structure.
  static const _uploadedLooseMock = <_OneShortItem>[
    _OneShortItem(
      id: 'os_u_loose_1',
      title: '朝の踏切',
      description: '待っている間に思い出した、昔の会話。',
      jlptLevel: 'N5',
    ),
  ];

  static const _savedLooseMock = <_OneShortItem>[
    _OneShortItem(
      id: 'os_s_loose_1',
      title: '季節のあいさつ',
      description: '手紙の書き出しと、短い近況。',
      jlptLevel: 'N3',
    ),
  ];

  late List<_StoryFolder> _uploadedFolders;
  late List<_StoryFolder> _savedFolders;
  late List<_OneShortItem> _uploadedLooseItems;
  late List<_OneShortItem> _savedLooseItems;
  bool _publishedLoadedRemote = false;

  /// Briefly emphasizes the card for [highlightDraftId] from the route (e.g. after publish).
  String? _pulseDraftId;
  Timer? _pulseTimer;
  ProviderSubscription<int>? _processingRefreshSub;
  ProviderSubscription<int>? _savedRefreshSub;

  late final PageController _pageController;
  late final TabController _tabController;
  late final AnimationController _profileDrawerController;

  /// True while the user is performing a horizontal drawer pan (page or panel).
  final ValueNotifier<bool> _profileDrawerPanSession = ValueNotifier(false);

  ValueNotifier<bool>? _obscuresDock;

  @override
  void initState() {
    super.initState();
    final initialTab = (widget.initialTabIndex ?? 0).clamp(0, 2);
    _pageController = PageController(initialPage: initialTab);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );
    _profileDrawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _tabController.addListener(_onTabChanged);
    _uploadedFolders = List<_StoryFolder>.from(_uploadedFoldersMock);
    _savedFolders = List<_StoryFolder>.from(_savedFoldersMock);
    _uploadedLooseItems = List<_OneShortItem>.from(_uploadedLooseMock);
    _savedLooseItems = List<_OneShortItem>.from(_savedLooseMock);
    _profileDrawerController.addListener(_syncProfileDrawerDockOcclusion);
    _pulseDraftId = widget.highlightDraftId;
    _scheduleProcessingPulseEnd();
    _processingRefreshSub = ref.listenManual<int>(
      profileProcessingListRefreshProvider,
      (previous, next) {
        if (!mounted) return;
        unawaited(
          ref.read(profileWorkspaceDraftPagerProvider.notifier).refresh(),
        );
        if (RemoteBackendConfig.useRemoteDrafts) {
          unawaited(
            ref.read(profilePublishedMonoPagerProvider.notifier).refresh(),
          );
        }
      },
    );

    _savedRefreshSub = ref.listenManual<int>(
      profileSavedListRefreshProvider,
      (previous, next) {
        if (!mounted) return;
        if (!RemoteBackendConfig.useRemoteDrafts) return;
        final session = ref.read(authSessionProvider);
        if (session is! AuthSessionAuthenticated) return;
        unawaited(ref.read(profileSavedMonoPagerProvider.notifier).refresh());
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(profileWorkspaceDraftPagerProvider.notifier).loadFirstPage(),
      );
    });
    if (!RemoteBackendConfig.useRemoteDrafts) {
      _debugLogPublishedLoad(
        stage: 'skip (useRemoteDrafts off)',
        willCallGet: false,
      );
    } else {
      // Defer published first load to the next frame so workspace [loadFirstPage] can
      // own the first request epoch, reducing back-to-back races with [refresh] (tabs,
      // [profileProcessingListRefreshProvider]) on cold open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _debugLogPublishedLoad(
          stage: 'before GET /v1/published-monos (pager)',
          willCallGet: true,
        );
        unawaited(
          ref
              .read(profilePublishedMonoPagerProvider.notifier)
              .loadFirstPage()
              .then((_) {
            if (!mounted) return;
            final p = ref.read(profilePublishedMonoPagerProvider);
            _debugLogPublishedLoad(
              stage: 'after pager loadFirstPage',
              willCallGet: true,
              rawCount: p.items.length,
              mappedCount: p.items.length,
            );
            if (!mounted) return;
            setState(() {
              _publishedLoadedRemote = true;
              _uploadedFolders = const <_StoryFolder>[];
            });
          }),
        );
      });
    }
  }

  /// When set, a Published list row is hidden only if this id is in the Workspace
  /// "Editing" set — not merely because a mono has a [sourceDraftId] field.
  ///
  /// Rows from [GET /v1/published-monos] are never hidden here: local read-only
  /// signature / resume state can spuriously mark a draft as "Editing" while the
  /// same story must stay visible in Published.
  static bool _hidePublishedItemForWorkspaceEditing(
    _OneShortItem it,
    Set<String> editingWorkspaceDraftIds,
  ) {
    if (it.isBackendPublished) {
      return false;
    }
    final sid = it.sourceDraftId?.trim();
    if (sid == null || sid.isEmpty) return false;
    return editingWorkspaceDraftIds.contains(sid);
  }

  void _debugLogPublishedLoad({
    required String stage,
    required bool willCallGet,
    int? rawCount,
    int? mappedCount,
  }) {
    final qTab = (() {
      if (!mounted) return null;
      try {
        return GoRouterState.of(context).uri.queryParameters['tab'];
      } catch (_) {
        return null;
      }
    })();
    final initialTabW = widget.initialTabIndex;
    var tabIndex = 0;
    try {
      tabIndex = _tabController.index;
    } catch (_) {}

    final editingIdSet = _workspaceEditingDraftIdsForPublishedHide();
    final looseForLog = _publishedLooseRowsForDebugLog();
    var displayed = 0;
    for (final it in looseForLog) {
      if (!_hidePublishedItemForWorkspaceEditing(it, editingIdSet)) {
        displayed++;
      }
    }
    final rc = rawCount == null ? '—' : '$rawCount';
    final mc = mappedCount == null ? '—' : '$mappedCount';

    // One-line trace (visible in debug/profile consoles).
    debugPrint(
      '[Profile Published] $stage: useRemote=${RemoteBackendConfig.useRemoteDrafts} base=${RemoteBackendConfig.apiBaseUrl} routeTab=$qTab initialTabIndex=$initialTabW currentTabIndex=$tabIndex willGET=$willCallGet raw=$rc mapped=$mc editingCount=${editingIdSet.length} shown=$displayed loose=${looseForLog.length} publishedLoadRan=${stage != 'skip (useRemoteDrafts off)'}',
    );

    if (kDebugMode) {
      debugPrint(
        '[Profile Published] editingIds=$editingIdSet',
      );
      for (var i = 0; i < looseForLog.length; i++) {
        final it = looseForLog[i];
        final sid = it.sourceDraftId?.trim();
        final inEditing = sid != null &&
            sid.isNotEmpty &&
            editingIdSet.contains(sid) &&
            !it.isBackendPublished;
        // Pre-fix behavior (mock rows only) for diagnosis logging.
        final wouldHideIfMockRule = sid != null &&
            sid.isNotEmpty &&
            editingIdSet.contains(sid) &&
            !it.isBackendPublished;
        final wouldHideWithBackendRowsToo =
            sid != null && sid.isNotEmpty && editingIdSet.contains(sid);
        if (wouldHideWithBackendRowsToo) {
          debugPrint(
            '[Profile Published] hideReason[$i] id=${it.id} sourceDraftId=$sid '
            'isBackend=${it.isBackendPublished} inEditingSet=$inEditing '
            'wouldHideOldRule(allRows)=$wouldHideWithBackendRowsToo wouldHideNewRule(mocks)=$wouldHideIfMockRule',
          );
        }
      }
    }
  }

  List<_OneShortItem> _publishedLooseRowsForDebugLog() {
    if (!RemoteBackendConfig.useRemoteDrafts) return _uploadedLooseItems;
    return _mapPublishedDtosToLooseItems(
      ref.read(profilePublishedMonoPagerProvider).items,
    );
  }

  List<_OneShortItem> _publishedLooseRowsForUi(
    PaginatedState<PublishedMonoListItemDto> pager,
  ) {
    if (pager.isInitialLoading && pager.items.isEmpty && pager.error == null) {
      return _uploadedLooseItems;
    }
    return _mapPublishedDtosToLooseItems(pager.items);
  }

  List<_OneShortItem> _mapPublishedDtosToLooseItems(
    List<PublishedMonoListItemDto> items,
  ) {
    return [
      for (final m in items)
        _OneShortItem(
          id: m.id,
          sourceDraftId: m.sourceDraftId,
          title: m.title.trim().isEmpty ? 'Untitled' : m.title.trim(),
          description: m.description.trim(),
          jlptLevel: m.level.trim().isEmpty ? '—' : m.level.trim(),
          isBackendPublished: true,
          thumbnailUrl: m.coverImageUrl,
          categoryText: m.category.trim().isEmpty ? null : m.category.trim(),
          targetDurationText: m.targetDurationLabel,
          publishBadgeText: publishBadgeLabel(
            displayKindFromApi(m.displayPublishKind),
          ),
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _obscuresDock ??= ProfilePushDrawerDockScope.maybeObscuresDockOf(context);
  }

  void _scheduleProcessingPulseEnd() {
    _pulseTimer?.cancel();
    if (_pulseDraftId == null) return;
    _pulseTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _pulseDraftId = null);
      _stripHighlightQueryFromProfileRoute();
    });
  }

  void _stripHighlightQueryFromProfileRoute() {
    if (!mounted) return;
    final state = GoRouterState.of(context);
    if (!state.uri.queryParameters.containsKey('highlight')) return;
    final next = Map<String, String>.from(state.uri.queryParameters);
    next.remove('highlight');
    context.go(Uri(path: state.uri.path, queryParameters: next).toString());
  }

  /// Draft ids in Workspace "Editing" (used to hide duplicate mock Published rows only).
  Set<String> _workspaceEditingDraftIdsForPublishedHide() {
    final p = ref.read(profileWorkspaceDraftPagerProvider);
    return {
      for (final s in p.items)
        if (effectiveDraftListWorkspaceState(s) == 'editing') s.draftId.trim(),
    };
  }

  void _syncProfileDrawerDockOcclusion() {
    if (!mounted) return;
    final n = _obscuresDock ??
        ProfilePushDrawerDockScope.maybeObscuresDockOf(context);
    _obscuresDock ??= n;
    if (n == null) return;
    final obscured = _profileDrawerController.value > 0.001;
    if (n.value != obscured) n.value = obscured;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      final idx = (widget.initialTabIndex ?? 0).clamp(0, 2);
      if (_tabController.index != idx) {
        _tabController.index = idx;
        _pageController.jumpToPage(idx);
      }
    }
    if (widget.highlightDraftId != oldWidget.highlightDraftId &&
        widget.highlightDraftId != null) {
      setState(() => _pulseDraftId = widget.highlightDraftId);
      _scheduleProcessingPulseEnd();
    }
  }

  /// Sync [PageView] when the user selects a tab (reference: older Profile screen).
  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index != _pageController.page?.round()) {
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (_tabController.index == 1) {
      unawaited(
          ref.read(profileWorkspaceDraftPagerProvider.notifier).refresh());
    }
    if (_tabController.index == 0 && RemoteBackendConfig.useRemoteDrafts) {
      final published = ref.read(profilePublishedMonoPagerProvider);
      if (!published.isInitialLoading && !published.isRefreshing) {
        unawaited(
          ref.read(profilePublishedMonoPagerProvider.notifier).refresh(),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _processingRefreshSub?.close();
    _processingRefreshSub = null;
    _savedRefreshSub?.close();
    _savedRefreshSub = null;
    _profileDrawerController.removeListener(_syncProfileDrawerDockOcclusion);
    _obscuresDock?.value = false;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    _profileDrawerPanSession.dispose();
    _profileDrawerController.dispose();
    super.dispose();
  }

  static const _drawerAnimDuration = Duration(milliseconds: 280);
  static const _drawerSnapDuration = Duration(milliseconds: 240);

  Future<void> _closeProfilePushDrawer() {
    return _profileDrawerController.animateTo(
      0,
      duration: _drawerAnimDuration,
      curve: Curves.easeInCubic,
    );
  }

  void _handleProfileMenu() {
    if (_profileDrawerController.value > 0.5) {
      _profileDrawerController.animateTo(
        0,
        duration: _drawerAnimDuration,
        curve: Curves.easeInCubic,
      );
    } else {
      _obscuresDock?.value = true;
      _profileDrawerController.animateTo(
        1,
        duration: _drawerAnimDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onProfileDrawerDragStart() {
    if (_profileDrawerController.value <= 0.001) return;
    _profileDrawerPanSession.value = true;
    _profileDrawerController.stop();
  }

  void _onProfileDrawerDragUpdate(double drawerW, DragUpdateDetails details) {
    if (!_profileDrawerPanSession.value) return;
    final delta = details.delta.dx;
    final next =
        (_profileDrawerController.value - delta / drawerW).clamp(0.0, 1.0);
    _profileDrawerController.value = next;
  }

  void _snapProfileDrawerAfterDrag(double drawerW, DragEndDetails details) {
    if (!_profileDrawerPanSession.value) return;
    _profileDrawerPanSession.value = false;

    final v = details.velocity.pixelsPerSecond.dx;
    final t = _profileDrawerController.value;
    const flingTowardClose = 420.0;
    const flingTowardOpen = -420.0;

    void snapTo(double target) {
      _profileDrawerController.animateTo(
        target.clamp(0.0, 1.0),
        duration: _drawerSnapDuration,
        curve: Curves.easeOutCubic,
      );
    }

    if (v > flingTowardClose) {
      snapTo(0);
    } else if (v < flingTowardOpen) {
      snapTo(1);
    } else if (t < 0.32) {
      snapTo(0);
    } else if (t > 0.68) {
      snapTo(1);
    } else if (t < 0.5) {
      snapTo(0);
    } else {
      snapTo(1);
    }
  }

  void _onProfileDrawerDragCancel() {
    _profileDrawerPanSession.value = false;
  }

  Future<bool> _publishedAddToCollectionLoose(Set<String> ids) async {
    if (!RemoteBackendConfig.useRemoteDrafts) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collections are coming soon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    final safeIds = PublishedMonoIdSanitizer.sanitize(ids.toList());
    if (safeIds.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stories are still syncing. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    final session = ref.read(authSessionProvider);
    if (session is! AuthSessionAuthenticated) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return showAddToCollectionSheet(
      context: context,
      publishedMonoIds: safeIds,
    );
  }

  Future<void> _createRemoteCreatorCollection() async {
    if (!RemoteBackendConfig.useRemoteDrafts) return;
    final session = ref.read(authSessionProvider);
    if (session is! AuthSessionAuthenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Unify collection creation UX and POST wiring with the Add-to-collection sheet logic.
    unawaited(
      showAddToCollectionSheet(
        context: context,
        publishedMonoIds: const <String>[],
        mode: AddToCollectionSheetMode.createOnly,
        startInCreateMode: true,
      ),
    );
  }

  /// Horizontal pan to open/close the push drawer (shared by main layer + drawer panel).
  Widget _wrapProfileDrawerHorizontalPan({
    required Widget child,
    required double drawerW,
    required double t,
    required bool enableDrawerDrag,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart:
          t > 0.001 ? (_) => _onProfileDrawerDragStart() : null,
      onHorizontalDragUpdate: enableDrawerDrag
          ? (details) => _onProfileDrawerDragUpdate(drawerW, details)
          : null,
      onHorizontalDragEnd: enableDrawerDrag
          ? (details) => _snapProfileDrawerAfterDrag(drawerW, details)
          : null,
      onHorizontalDragCancel:
          enableDrawerDrag ? _onProfileDrawerDragCancel : null,
      child: child,
    );
  }

  Future<void> _renameFolder({
    required bool saved,
    required _StoryFolder folder,
  }) async {
    final next = await _showCollectionNameBottomSheet(
      context,
      headline: 'Rename collection',
      initialName: folder.name,
    );
    if (!mounted) return;
    if (next == null) return;
    final trimmed = next.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (saved) {
        _savedFolders = [
          for (final f in _savedFolders)
            f.id == folder.id
                ? _StoryFolder(
                    id: f.id,
                    name: trimmed,
                    items: f.items,
                    isPrivate: f.isPrivate,
                  )
                : f,
        ];
      } else {
        _uploadedFolders = [
          for (final f in _uploadedFolders)
            f.id == folder.id
                ? _StoryFolder(
                    id: f.id,
                    name: trimmed,
                    items: f.items,
                    isPrivate: f.isPrivate,
                  )
                : f,
        ];
      }
    });
  }

  Future<void> _deleteFolder({
    required bool saved,
    required _StoryFolder folder,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          'Delete “${folder.name}”? This does not delete the stories themselves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    setState(() {
      if (saved) {
        _savedFolders = _savedFolders.where((f) => f.id != folder.id).toList();
      } else {
        _uploadedFolders =
            _uploadedFolders.where((f) => f.id != folder.id).toList();
      }
    });
  }

  MonoFeedItem _asMonoFeedItem(_OneShortItem it) {
    final d = it.description.trim();
    final sid = it.sourceDraftId?.trim();
    return MonoFeedItem(
      id: 'profile-${it.id}',
      writerName: 'Just4withYou',
      writerHandle: '@just4withyou',
      level: it.jlptLevel,
      contentType: MonoContentType.story,
      title: it.title,
      bodyText: '${it.description}\n\n${it.description}',
      storyDescription: d,
      coverImageUrl: it.thumbnailUrl,
      sourceDraftId: (sid != null && sid.isNotEmpty) ? sid : null,
    );
  }

  Future<void> _openPublishedTabReader(
    List<_OneShortItem> list,
    int idx,
  ) async {
    final it = list[idx];
    if (!it.isBackendPublished) {
      _openFolderAwareReader(list, idx, fromSaved: false);
      return;
    }
    try {
      final repo = ref.read(remotePublishedMonoRepositoryForProfileProvider);
      final d = await repo.get(it.id);
      if (!mounted) return;
      final feed = monoFeedItemFromPublishedMonoDetail(d);
      context.push(
        '/mono-reader',
        extra: <String, Object?>{
          'items': <MonoFeedItem>[feed],
          'initialIndex': 0,
          'readerMenuOrigin': MonoReaderMenuOrigin.profileUploaded,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is PublishedMonoHiddenWhileEditingException
          ? e.message
          : 'Could not open story: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _openFolderAwareReader(
    List<_OneShortItem> folderItems,
    int tappedIndex, {
    required bool fromSaved,
  }) {
    final items = folderItems.map(_asMonoFeedItem).toList(growable: false);
    final safeIndex = tappedIndex.clamp(0, math.max(0, items.length - 1));
    context.push(
      '/mono-reader',
      extra: <String, Object?>{
        'items': items,
        'initialIndex': safeIndex,
        'readerMenuOrigin': fromSaved
            ? MonoReaderMenuOrigin.profileSaved
            : MonoReaderMenuOrigin.profileUploaded,
        if (fromSaved)
          'onUnsavedMonoFeedItemId': (String monoId) {
            const prefix = 'profile-';
            if (!monoId.startsWith(prefix)) return;
            final rawId = monoId.substring(prefix.length);
            if (!mounted) return;
            setState(() {
              _savedLooseItems.removeWhere((e) => e.id == rawId);
              _savedFolders = [
                for (final f in _savedFolders)
                  _StoryFolder(
                    id: f.id,
                    name: f.name,
                    items: [
                      for (final it in f.items)
                        if (it.id != rawId) it
                    ],
                    isPrivate: f.isPrivate,
                  ),
              ];
            });
          },
      },
    );
  }

  Future<void> _showSavedLooseItemSheet(_OneShortItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      // Root navigator so system Back dismisses this sheet before any shell route pops.
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 16 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withOpacity(0.62),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _savedLooseItems.removeWhere((e) => e.id == item.id);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Unsave'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add note - Coming soon'),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showUploadedLooseItemSheet(_OneShortItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 16 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withOpacity(0.62),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (RemoteBackendConfig.useRemoteDrafts &&
                            item.isBackendPublished) {
                          ref
                              .read(profilePublishedMonoPagerProvider.notifier)
                              .removeItemsByIds({item.id});
                        } else {
                          setState(() {
                            _uploadedLooseItems
                                .removeWhere((e) => e.id == item.id);
                          });
                        }
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: const Color(0xFFDF3B3B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (!context.mounted) return;
                        await CreatorDraftResumeFlow
                            .tryResumeFromPublishedSurface(
                          context,
                          item.id.trim(),
                          sourceDraftId: item.sourceDraftId,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProcessingDraftSheet(_OneShortItem item) async {
    final draft =
        await ref.read(storyDraftRepositoryProvider).loadDraft(item.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final ro = draft == null ? null : computeReadOnlyReady(draft);
        final fl = draft == null ? null : computeFullLearnReady(draft);
        final canReadOnly = ro?.ready == true;
        final canFullLearn = fl?.ready == true;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                item.processingStatusLabel ?? 'Draft only',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.62),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withOpacity(0.62),
                    ),
              ),
              if ((ro?.unmetMessages.isNotEmpty ?? false) ||
                  (fl?.unmetMessages.isNotEmpty ?? false)) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Readiness',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (ro != null && !ro.ready) ...[
                          Text(
                            'Read-only not ready:',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withOpacity(0.72),
                                ),
                          ),
                          const SizedBox(height: 4),
                          for (final m in ro.unmetMessages)
                            Text(
                              '• $m',
                              style:
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: Colors.black.withOpacity(0.65),
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          const SizedBox(height: 10),
                        ],
                        if (fl != null && !fl.ready) ...[
                          Text(
                            'Full Learn not ready:',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withOpacity(0.72),
                                ),
                          ),
                          const SizedBox(height: 4),
                          for (final m in fl.unmetMessages)
                            Text(
                              '• $m',
                              style:
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: Colors.black.withOpacity(0.65),
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: !canReadOnly
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Upload Read-only (coming soon)'),
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Upload Read-only'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: !canFullLearn
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Upload Full Learn (coming soon)'),
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Upload Full Learn'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        unawaited(() async {
                          final repo = ref.read(storyDraftRepositoryProvider);
                          await repo.deleteDraft(item.id);
                          ref
                              .read(storyCreatorDraftProvider.notifier)
                              .syncIfDraftWasRemovedExternally(item.id);
                          ref
                              .read(profileWorkspaceDraftPagerProvider.notifier)
                              .removeDraftById(item.id);
                        }());
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: const Color(0xFFDF3B3B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: draft == null
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              unawaited(
                                CreatorDraftResumeFlow.resumeFromProcessing(
                                  context,
                                  item.id,
                                  publishState: draft.publishState,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateFolderDialog({
    required void Function(String name) onCreate,
  }) async {
    final name = await _showCollectionNameBottomSheet(
      context,
      headline: 'New collection',
      initialName: '',
    );
    if (!mounted) return;
    if (name == null) return;
    final v = name.trim();
    if (v.isEmpty) return;
    onCreate(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Calculate bottom padding: nav bar height + device safe area + extra spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const double bottomNavHeight = 64.0; // Navigation bar height
    const double extraBottomPadding = 18.0; // Extra spacing to clear dock

    final session = ref.watch(authSessionProvider);
    final publicProfileAsync = ref.watch(currentUserPublicProfileProvider);
    final publishedPagerState = ref.watch(profilePublishedMonoPagerProvider);

    final String ownerDisplayName;
    final String ownerHandleLine;
    final String ownerBio;
    final String? ownerAvatarUrl;
    if (session is AuthSessionAuthenticated) {
      final remote = publicProfileAsync.asData?.value;
      if (remote != null) {
        ownerDisplayName = remote.effectiveDisplayName;
        ownerHandleLine = (remote.handle ?? '').trim();
        final rb = (remote.bio ?? '').trim();
        ownerBio =
            rb.isNotEmpty ? rb : 'Japanese micro-stories • daily reading';
        final au = (remote.avatarUrl ?? '').trim();
        ownerAvatarUrl = au.isNotEmpty ? au : null;
      } else {
        final dn = (session.user.displayName ?? '').trim();
        ownerDisplayName =
            dn.isNotEmpty ? dn : (session.user.email ?? 'Creator');
        ownerHandleLine = (session.user.handle ?? '').trim();
        ownerBio = 'Japanese micro-stories • daily reading';
        ownerAvatarUrl = null;
      }
    } else {
      ownerDisplayName = 'Guest';
      ownerHandleLine = '';
      ownerBio = '';
      ownerAvatarUrl = null;
    }

    final publishedStatLabel = publishedCountLabelForOwnerHeader(
      useRemoteBackend: RemoteBackendConfig.useRemoteDrafts,
      mockFallbackCount: _uploadedMock.length,
      publishedState: publishedPagerState,
    );

    final followersStatLabel = RemoteBackendConfig.useRemoteDrafts &&
            session is AuthSessionAuthenticated
        ? socialMetricLabel(publicProfileAsync, (p) => p.followersCount)
        : formatSocialCount(0);

    final followingStatLabel = RemoteBackendConfig.useRemoteDrafts &&
            session is AuthSessionAuthenticated
        ? socialMetricLabel(publicProfileAsync, (p) => p.followingCount)
        : formatSocialCount(0);

    final profileScaffold = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false, // Handle padding manually to account for nav bar
        child: Column(
          children: [
            _ProfileTopHeaderBar(
              onAdd: () => context.push('/profile/share'),
              onNotifications: () => context.push('/profile/notifications'),
              onMenu: _handleProfileMenu,
            ),
            _ProfileSummaryRow(
              displayName: ownerDisplayName,
              handle: ownerHandleLine,
              avatarUrl: ownerAvatarUrl,
              bio: ownerBio,
              uploadedCount: publishedStatLabel,
              followersCount: followersStatLabel,
              followingCount: followingStatLabel,
            ),
            const SizedBox(height: 8),
            const _PublicProfilePreviewCard(),
            _ProfileIconTabs(
              controller: _tabController,
              onTap: (i) => _tabController.animateTo(i),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _profileDrawerController,
                builder: (context, _) {
                  final workspacePager =
                      ref.watch(profileWorkspaceDraftPagerProvider);
                  final workspaceProcessingRows = [
                    for (final s in workspacePager.items)
                      if (effectiveDraftListWorkspaceState(s) != 'synced')
                        _ProcessingDraftItem.fromSummary(s),
                  ];
                  return PageView(
                    physics: _profileDrawerController.value > 0.001
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    controller: _pageController,
                    onPageChanged: (index) {
                      if (_tabController.index != index) {
                        _tabController.animateTo(index);
                      }
                    },
                    children: [
                      () {
                        final editingIds = {
                          for (final s in workspacePager.items)
                            if (effectiveDraftListWorkspaceState(s) ==
                                'editing')
                              s.draftId.trim(),
                        };
                        final filteredFolders =
                            RemoteBackendConfig.useRemoteDrafts
                                ? const <_StoryFolder>[]
                                : [
                                    for (final f in _uploadedFolders)
                                      _StoryFolder(
                                        id: f.id,
                                        name: f.name,
                                        isPrivate: f.isPrivate,
                                        items: [
                                          for (final it in f.items)
                                            if (!_hidePublishedItemForWorkspaceEditing(
                                              it,
                                              editingIds,
                                            ))
                                              it,
                                        ],
                                      ),
                                  ];
                        final publishedPager =
                            RemoteBackendConfig.useRemoteDrafts
                                ? ref.watch(profilePublishedMonoPagerProvider)
                                : null;
                        final publishedSource = publishedPager != null
                            ? _publishedLooseRowsForUi(publishedPager)
                            : _uploadedLooseItems;
                        final filteredLoose = [
                          for (final it in publishedSource)
                            if (!_hidePublishedItemForWorkspaceEditing(
                              it,
                              editingIds,
                            ))
                              it,
                        ];
                        return _FolderGroupList(
                          title: 'Published',
                          folders: filteredFolders,
                          looseItems: filteredLoose,
                          bottomPadding: bottomNavHeight +
                              bottomPadding +
                              extraBottomPadding,
                          trailingAction: _OneShortCardAction.edit,
                          isSavedSection: false,
                          onLooseListNearEnd:
                              RemoteBackendConfig.useRemoteDrafts
                                  ? () => ref
                                      .read(profilePublishedMonoPagerProvider
                                          .notifier)
                                      .loadMore()
                                  : null,
                          onStoryTap: (list, idx) {
                            unawaited(_openPublishedTabReader(list, idx));
                          },
                          onLooseItemDetail: _showUploadedLooseItemSheet,
                          onCreateFolder: RemoteBackendConfig.useRemoteDrafts
                              ? () =>
                                  unawaited(_createRemoteCreatorCollection())
                              : () => _openCreateFolderDialog(
                                    onCreate: (name) => setState(() {
                                      _uploadedFolders = [
                                        ..._uploadedFolders,
                                        _StoryFolder(
                                          id: 'uf_${DateTime.now().millisecondsSinceEpoch}',
                                          name: name,
                                          items: const [],
                                          isPrivate: false,
                                        ),
                                      ];
                                    }),
                                  ),
                          onRenameFolder: (f) =>
                              _renameFolder(saved: false, folder: f),
                          onDeleteFolder: (f) =>
                              _deleteFolder(saved: false, folder: f),
                          onPublishedAddToCollection:
                              _publishedAddToCollectionLoose,
                        );
                      }(),
                      _ProcessingDraftManagerTab(
                        items: workspaceProcessingRows,
                        pagerState: workspacePager,
                        highlightDraftId: _pulseDraftId,
                        bottomPadding: bottomNavHeight +
                            bottomPadding +
                            extraBottomPadding,
                        onChanged: () => unawaited(
                          ref
                              .read(profileWorkspaceDraftPagerProvider.notifier)
                              .refresh(),
                        ),
                        onNearEnd: () => unawaited(
                          ref
                              .read(profileWorkspaceDraftPagerProvider.notifier)
                              .loadMore(),
                        ),
                      ),
                      RemoteBackendConfig.useRemoteDrafts
                          ? _ProfileSavedRemoteTab(
                              bottomPadding: bottomNavHeight +
                                  bottomPadding +
                                  extraBottomPadding,
                            )
                          : _FolderGroupList(
                              title: 'Saved',
                              folders: _savedFolders,
                              looseItems: _savedLooseItems,
                              bottomPadding: bottomNavHeight +
                                  bottomPadding +
                                  extraBottomPadding,
                              trailingAction: _OneShortCardAction.bookmark,
                              isSavedSection: true,
                              onStoryTap: (list, idx) => _openFolderAwareReader(
                                list,
                                idx,
                                fromSaved: true,
                              ),
                              onLooseItemDetail: _showSavedLooseItemSheet,
                              onCreateFolder: () => _openCreateFolderDialog(
                                onCreate: (name) => setState(() {
                                  _savedFolders = [
                                    ..._savedFolders,
                                    _StoryFolder(
                                      id: 'sf_${DateTime.now().millisecondsSinceEpoch}',
                                      name: name,
                                      items: const [],
                                      isPrivate: false,
                                    ),
                                  ];
                                }),
                              ),
                              onRenameFolder: (f) =>
                                  _renameFolder(saved: true, folder: f),
                              onDeleteFolder: (f) =>
                                  _deleteFolder(saved: true, folder: f),
                              onBulkUnsaveLoose: (ids) => setState(() {
                                _savedLooseItems = _savedLooseItems
                                    .where((e) => !ids.contains(e.id))
                                    .toList();
                              }),
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: _profileDrawerController.isDismissed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_profileDrawerController.isDismissed) {
          _profileDrawerController.animateTo(
            0,
            duration: _drawerAnimDuration,
            curve: Curves.easeInCubic,
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final drawerW = (maxW * 0.78).clamp(260.0, 320.0);

          return AnimatedBuilder(
            animation: _profileDrawerController,
            child: profileScaffold,
            builder: (context, child) {
              final t = _profileDrawerController.value;
              final enableDrawerDrag =
                  t > 0.001 || _profileDrawerPanSession.value;
              final dx = -drawerW * t;
              final radius = 14.0 * t;
              final scale = 1.0 - 0.012 * t;
              final sheetRadius = BorderRadius.horizontal(
                right: Radius.circular(radius),
              );

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: drawerW,
                    child: _wrapProfileDrawerHorizontalPan(
                      drawerW: drawerW,
                      t: t,
                      enableDrawerDrag: enableDrawerDrag,
                      child: Material(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: SafeArea(
                          bottom: true,
                          top: true,
                          left: false,
                          right: true,
                          child: ProfileNavigationDrawer(
                            hostContext: context,
                            displayName: 'Just4withYou',
                            handle: '@just4withyou',
                            closeDrawer: _closeProfilePushDrawer,
                            lockScrollForHorizontalPan:
                                _profileDrawerPanSession,
                            drawerMotion: _profileDrawerController,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: _wrapProfileDrawerHorizontalPan(
                        drawerW: drawerW,
                        t: t,
                        enableDrawerDrag: enableDrawerDrag,
                        child: SizedBox(
                          width: maxW,
                          height: maxH,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: sheetRadius,
                              boxShadow: t > 0.01
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.14 * t),
                                        blurRadius: 18 * t,
                                        offset: Offset(5 * t, 0),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: sheetRadius,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  child!,
                                  if (t > 0.02)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 40,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: _closeProfilePushDrawer,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FolderGroupList extends StatefulWidget {
  final String title;
  final List<_StoryFolder> folders;
  final List<_OneShortItem> looseItems;
  final double bottomPadding;
  final _OneShortCardAction trailingAction;
  final bool isSavedSection;
  final void Function(List<_OneShortItem> folderItems, int tappedIndex)?
      onStoryTap;

  /// Content detail sheet opener (Saved/Published loose items only). Not used for organization actions.
  final void Function(_OneShortItem item)? onLooseItemDetail;
  final VoidCallback? onCreateFolder;
  final void Function(_StoryFolder folder)? onRenameFolder;
  final void Function(_StoryFolder folder)? onDeleteFolder;
  final void Function(Set<String> ids)? onBulkUnsaveLoose;

  /// Remote Published: open Add to collection sheet; mock/offline uses placeholder snackbar when null.
  final Future<bool> Function(Set<String> ids)? onPublishedAddToCollection;

  /// Published-tab infinite scroll hook (monos filter only); safe no-op when null.
  final VoidCallback? onLooseListNearEnd;

  const _FolderGroupList({
    required this.title,
    required this.folders,
    required this.looseItems,
    required this.bottomPadding,
    required this.trailingAction,
    required this.isSavedSection,
    this.onStoryTap,
    this.onLooseItemDetail,
    this.onCreateFolder,
    this.onRenameFolder,
    this.onDeleteFolder,
    this.onBulkUnsaveLoose,
    this.onPublishedAddToCollection,
    this.onLooseListNearEnd,
  });

  @override
  State<_FolderGroupList> createState() => _FolderGroupListState();
}

class _ProfileSavedRemoteTab extends ConsumerStatefulWidget {
  const _ProfileSavedRemoteTab({required this.bottomPadding});

  final double bottomPadding;

  @override
  ConsumerState<_ProfileSavedRemoteTab> createState() =>
      _ProfileSavedRemoteTabState();
}

class _ProfileSavedRemoteTabState
    extends ConsumerState<_ProfileSavedRemoteTab> {
  bool _booted = false;

  void _ensureLoaded() {
    if (_booted) return;
    _booted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
          ref.read(profileSavedMonoPagerProvider.notifier).loadFirstPage());
    });
  }

  Future<void> _openReader(List<MonoFeedItem> list, int idx) async {
    final safe = idx.clamp(0, list.length - 1);
    if (!context.mounted) return;
    context.push(
      '/mono-reader',
      extra: <String, Object?>{
        'items': list,
        'initialIndex': safe,
        'readerMenuOrigin': MonoReaderMenuOrigin.profileSaved,
        'onUnsavedMonoFeedItemId': (String monoId) {
          ref
              .read(profileSavedMonoPagerProvider.notifier)
              .removeItemsByIds({monoId});
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider);

    if (session is! AuthSessionAuthenticated) {
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SavedLibraryCopy.guestTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  SavedLibraryCopy.guestBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    _ensureLoaded();

    final ps = ref.watch(profileSavedMonoPagerProvider);
    final items = ps.items;

    if (items.isEmpty && ps.isInitialLoading && ps.error == null) {
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (items.isEmpty && ps.error != null && !ps.isInitialLoading) {
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load saved stories.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${ps.error}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => unawaited(
                    ref
                        .read(profileSavedMonoPagerProvider.notifier)
                        .loadFirstPage(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (items.isEmpty && ps.error == null && !ps.isInitialLoading) {
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SavedLibraryCopy.emptyTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  SavedLibraryCopy.emptyBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(profileSavedMonoPagerProvider.notifier).refresh(),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 14, 16, widget.bottomPadding),
          itemCount: items.length + (ps.canLoadMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i >= items.length) {
              unawaited(
                  ref.read(profileSavedMonoPagerProvider.notifier).loadMore());
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final it = items[i];
            final title =
                (it.title ?? '').trim().isNotEmpty ? it.title! : 'Mono';
            final subtitle = it.storyDescription.trim();
            return Card(
              child: ListTile(
                onTap: () => unawaited(_openReader(items, i)),
                title: Text(title),
                subtitle: subtitle.isEmpty
                    ? null
                    : Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: IconButton(
                  tooltip: SavedLibraryCopy.removeFromSavedTooltip,
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: () async {
                    try {
                      await ref
                          .read(remoteMonoSocialRepositoryProvider)
                          .unbookmarkMono(it.monoIdForLearnRoutes);
                      ref
                          .read(profileSavedMonoPagerProvider.notifier)
                          .removeItemsByIds({it.id});
                      bumpProfileSavedListRefresh(
                        ProviderScope.containerOf(context, listen: false),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      final msg = e is StateError ? e.message : '$e';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FolderGroupListState extends State<_FolderGroupList> {
  _ProfileFolderFilter _filter = _ProfileFolderFilter.monos;
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};
  bool _bootedRemoteCreatorCollections = false;

  void _ensureRemoteCreatorCollectionsLoaded() {
    if (_bootedRemoteCreatorCollections) return;
    _bootedRemoteCreatorCollections = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Loads owner creator collections from backend (M8f3).
      final container = ProviderScope.containerOf(context, listen: false);
      unawaited(
        container.read(myCreatorCollectionsNotifierProvider.notifier).load(),
      );
    });
  }

  void _toggleSelect(_OneShortItem it) {
    if (RemoteBackendConfig.useRemoteDrafts &&
        !widget.isSavedSection &&
        !it.isBackendPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stories are still syncing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      if (_selectedIds.contains(it.id)) {
        _selectedIds.remove(it.id);
      } else {
        _selectedIds.add(it.id);
      }
    });
  }

  Future<void> _showOutsideOrgSheet(_OneShortItem it) async {
    final action = await showModalBottomSheet<String>(
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
            16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Multi Select'),
                subtitle: const Text(
                    'Select multiple items, then apply a bulk action.'),
                onTap: () => Navigator.pop(ctx, 'multi'),
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Add to collection'),
                onTap: () => Navigator.pop(ctx, 'add_folder'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'multi') {
      setState(() {
        _selecting = true;
        _selectedIds.add(it.id);
      });
      return;
    }
    if (action == 'add_folder') {
      if (widget.isSavedSection) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collections are coming soon.')),
        );
      } else if (RemoteBackendConfig.useRemoteDrafts &&
          !it.isBackendPublished) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stories are still syncing. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (widget.onPublishedAddToCollection != null) {
        unawaited(
            widget.onPublishedAddToCollection!(Set<String>.from({it.id})));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collections are coming soon.')),
        );
      }
    }
  }

  Widget _buildFilterOrSelectionBar() {
    if (_selecting && _filter == _ProfileFolderFilter.monos) {
      final count = _selectedIds.length;
      final bulkLabel = widget.isSavedSection ? 'Unsave' : 'Add to collection';
      final canBulk = count > 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$count selected',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selecting = false;
                    _selectedIds.clear();
                  }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: !canBulk
                      ? null
                      : () async {
                          if (widget.isSavedSection) {
                            widget.onBulkUnsaveLoose?.call(
                              Set<String>.from(_selectedIds),
                            );
                            setState(() {
                              _selecting = false;
                              _selectedIds.clear();
                            });
                          } else {
                            final fn = widget.onPublishedAddToCollection;
                            if (fn != null) {
                              final ok =
                                  await fn(Set<String>.from(_selectedIds));
                              if (mounted && ok) {
                                setState(() {
                                  _selecting = false;
                                  _selectedIds.clear();
                                });
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Collections are coming soon.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setState(() {
                                _selecting = false;
                                _selectedIds.clear();
                              });
                            }
                          }
                        },
                  child: Text(bulkLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _FilterRow(
        selected: _filter,
        onSelect: (v) => setState(() {
          _filter = v;
          _selecting = false;
          _selectedIds.clear();
        }),
        onCreate: _filter == _ProfileFolderFilter.collections
            ? widget.onCreateFolder
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_filter == _ProfileFolderFilter.collections &&
        !widget.isSavedSection &&
        RemoteBackendConfig.useRemoteDrafts) {
      _ensureRemoteCreatorCollectionsLoaded();
    }
    if (_filter == _ProfileFolderFilter.collections) {
      if (!widget.isSavedSection && RemoteBackendConfig.useRemoteDrafts) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(myCreatorCollectionsNotifierProvider);
              Widget body() {
                if (state.isLoading && state.collections.isEmpty) {
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (state.error != null && state.collections.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${state.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => unawaited(
                              ref
                                  .read(myCreatorCollectionsNotifierProvider
                                      .notifier)
                                  .load(),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (state.collections.isEmpty) {
                  return const Expanded(
                    child: Center(child: Text('No collections yet.')),
                  );
                }
                return Expanded(
                  child: ListView.separated(
                    itemCount: state.collections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = state.collections[i];
                      final countLabel =
                          '${c.itemCount} stor${c.itemCount == 1 ? 'y' : 'ies'}';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            context.push(
                              '/profile/creator-collections/detail',
                              extra: OwnerCreatorCollectionDetailArgs(
                                collection: c,
                              ),
                            );
                          },
                          child: CollectionListRow(
                            title: c.title.trim().isEmpty
                                ? 'Untitled'
                                : c.title.trim(),
                            countLabel: countLabel,
                            description: (c.description ?? '').trim().isEmpty
                                ? null
                                : c.description!.trim(),
                            coverImageUrl: c.coverImageUrl,
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.more_vert_rounded, size: 22),
                              onPressed: () {
                                unawaited(
                                  showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (ctx) {
                                      return SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                  Icons.edit_outlined),
                                              title: const Text('Rename'),
                                              onTap: () async {
                                                Navigator.of(ctx).pop();
                                                final controller =
                                                    TextEditingController(
                                                  text: c.title,
                                                );
                                                final newTitle =
                                                    await showDialog<String>(
                                                  context: context,
                                                  builder: (dctx) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Rename collection'),
                                                    content: TextField(
                                                      controller: controller,
                                                      autofocus: true,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText: 'Title',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(dctx)
                                                                .pop(),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(dctx)
                                                                .pop(controller
                                                                    .text),
                                                        child:
                                                            const Text('Save'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                final t =
                                                    (newTitle ?? '').trim();
                                                if (t.isEmpty) {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Title is required.'),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                    ),
                                                  );
                                                  return;
                                                }
                                                try {
                                                  await ref
                                                      .read(
                                                        myCreatorCollectionsNotifierProvider
                                                            .notifier,
                                                      )
                                                      .renameCollection(
                                                        collectionId: c.id,
                                                        title: t,
                                                      );
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text('$e'),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            ListTile(
                                              enabled: c.itemCount == 0,
                                              leading: Icon(
                                                Icons.delete_outline,
                                                color: c.itemCount == 0
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : null,
                                              ),
                                              title: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: c.itemCount == 0
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .error
                                                      : null,
                                                ),
                                              ),
                                              subtitle: c.itemCount == 0
                                                  ? null
                                                  : const Text(
                                                      'Remove all stories before deleting.',
                                                    ),
                                              onTap: c.itemCount == 0
                                                  ? () async {
                                                      Navigator.of(ctx).pop();
                                                      final ok =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (dctx) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              'Delete collection?'),
                                                          content: const Text(
                                                            'This deletes the collection only. Stories are not deleted.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          dctx)
                                                                      .pop(
                                                                          false),
                                                              child: const Text(
                                                                  'Cancel'),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          dctx)
                                                                      .pop(
                                                                          true),
                                                              child: const Text(
                                                                  'Delete'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (ok != true) return;
                                                      try {
                                                        await ref
                                                            .read(
                                                              myCreatorCollectionsNotifierProvider
                                                                  .notifier,
                                                            )
                                                            .deleteCollection(
                                                                c.id);
                                                      } catch (e) {
                                                        if (!context.mounted)
                                                          return;
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text('$e'),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  : null,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                              tooltip: 'Collection actions',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }

              // Important: keep the filter row + Add button visible even when empty/loading/error.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterOrSelectionBar(),
                  body(),
                ],
              );
            },
          ),
        );
      }
      final folderCount = widget.folders.length;
      final total = 1 + folderCount;
      final dividerColor =
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28);

      final list = ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
        itemCount: total,
        separatorBuilder: (context, index) {
          if (index == 0) {
            return const SizedBox(height: 4);
          }
          return Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
          );
        },
        itemBuilder: (context, i) {
          if (i == 0) {
            return _buildFilterOrSelectionBar();
          }
          final idx = i - 1;
          final f = widget.folders[idx];
          final n = f.items.length;
          final countLabel = '$n stor${n == 1 ? 'y' : 'ies'}';
          final hasMenu =
              widget.onRenameFolder != null || widget.onDeleteFolder != null;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _FolderDetailScreen(
                      folder: f,
                      isSavedSection: widget.isSavedSection,
                      trailingAction: widget.trailingAction,
                      onStoryTap: widget.onStoryTap,
                    ),
                  ),
                );
              },
              child: CollectionListRow(
                title: f.name,
                countLabel: countLabel,
                coverImageUrl: _firstStoryThumbnailUrl(f.items),
                trailing: !hasMenu
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Collection actions',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (v) {
                          if (v == 'rename') {
                            widget.onRenameFolder?.call(f);
                          }
                          if (v == 'delete') {
                            widget.onDeleteFolder?.call(f);
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      );
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: list,
      );
    }

    // Monos: loose mono story rows only (content-first feed rows; not card chrome).
    final looseCount = widget.looseItems.length;
    final total = 1 + looseCount;
    final dividerColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28);

    final list = ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
      itemCount: total,
      separatorBuilder: (context, index) {
        if (index == 0) {
          return const SizedBox(height: 4);
        }
        return Divider(
          height: 1,
          thickness: 0.5,
          color: dividerColor,
        );
      },
      itemBuilder: (context, i) {
        if (i == 0) {
          return _buildFilterOrSelectionBar();
        }
        final looseIdx = i - 1;
        final it = widget.looseItems[looseIdx];
        final selected = _selectedIds.contains(it.id);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selecting
                ? () => _toggleSelect(it)
                : (widget.onStoryTap == null
                    ? null
                    : () => widget.onStoryTap!(
                          widget.looseItems,
                          looseIdx,
                        )),
            onLongPress: () => _showOutsideOrgSheet(it),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: selected ? 0.85 : 1.0,
                  child: MonoStoryListRow(
                    title: it.title,
                    description: it.description,
                    jlptLevel: it.jlptLevel,
                    thumbnailUrl: it.thumbnailUrl,
                    onMenuTap: () => _showOutsideOrgSheet(it),
                    categoryText: it.categoryText,
                    durationText: it.targetDurationText,
                    publishBadgeText: it.publishBadgeText,
                  ),
                ),
                if (_selecting)
                  Positioned(
                    top: 8,
                    left: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.20)),
                      ),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 16,
                          color: selected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    Widget scrolled = list;
    if (widget.onLooseListNearEnd != null) {
      scrolled = NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n.metrics.axis != Axis.vertical) return false;
          if (n is! ScrollUpdateNotification) return false;
          final m = n.metrics;
          if (m.maxScrollExtent <= 0) return false;
          if (m.pixels >= m.maxScrollExtent - 220) {
            widget.onLooseListNearEnd!();
          }
          return false;
        },
        child: list,
      );
    }
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: scrolled,
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _ProfileFolderFilter selected;
  final ValueChanged<_ProfileFolderFilter> onSelect;
  final VoidCallback? onCreate;

  const _FilterRow({
    required this.selected,
    required this.onSelect,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip({
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: active ? Colors.white : Colors.black.withOpacity(0.80),
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    Widget? addButton() {
      if (onCreate == null) return null;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onCreate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.10)),
          ),
          child: Text(
            'Add',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.82),
              height: 1.0,
            ),
          ),
        ),
      );
    }

    final add = addButton();

    return Row(
      children: [
        chip(
          label: 'Monos',
          active: selected == _ProfileFolderFilter.monos,
          onTap: () => onSelect(_ProfileFolderFilter.monos),
        ),
        const SizedBox(width: 8),
        chip(
          label: 'Collections',
          active: selected == _ProfileFolderFilter.collections,
          onTap: () => onSelect(_ProfileFolderFilter.collections),
        ),
        const Spacer(),
        if (add != null) add,
      ],
    );
  }
}

class _StackedFolderThumb extends StatelessWidget {
  const _StackedFolderThumb({required this.items});

  final List<_OneShortItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const w = 54.0;
    const h = 54.0;
    final top = items.isNotEmpty ? items.first : null;

    Widget backCard(double dx, double dy, double alpha) {
      return Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade100.withOpacity(alpha),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
        ),
      );
    }

    return SizedBox(
      width: w + 10,
      height: h + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          backCard(6, 6, 0.55),
          backCard(3, 3, 0.75),
          Positioned(
            left: 0,
            top: 0,
            child: _StoryCoverThumb(
              thumbnailUrl: top?.thumbnailUrl,
              jlptLevel: top?.jlptLevel ?? '—',
              size: w,
              borderRadius: 14,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withOpacity(0.06),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.folder_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderDetailScreen extends StatelessWidget {
  const _FolderDetailScreen({
    required this.folder,
    required this.isSavedSection,
    required this.trailingAction,
    required this.onStoryTap,
  });

  final _StoryFolder folder;
  final bool isSavedSection;
  final _OneShortCardAction trailingAction;
  final void Function(List<_OneShortItem> folderItems, int tappedIndex)?
      onStoryTap;

  @override
  Widget build(BuildContext context) {
    // Deprecated: kept for file-local history. Use [_FolderDetailScreenStateful].
    return _FolderDetailScreenStateful(
      folder: folder,
      isSavedSection: isSavedSection,
      trailingAction: trailingAction,
      onStoryTap: onStoryTap,
    );
  }
}

class _FolderDetailScreenStateful extends StatefulWidget {
  const _FolderDetailScreenStateful({
    required this.folder,
    required this.isSavedSection,
    required this.trailingAction,
    required this.onStoryTap,
  });

  final _StoryFolder folder;
  final bool isSavedSection;
  final _OneShortCardAction trailingAction;
  final void Function(List<_OneShortItem> folderItems, int tappedIndex)?
      onStoryTap;

  @override
  State<_FolderDetailScreenStateful> createState() =>
      _FolderDetailScreenStatefulState();
}

class _FolderDetailScreenStatefulState
    extends State<_FolderDetailScreenStateful> {
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};

  void _toggle(_OneShortItem it) {
    setState(() {
      if (_selectedIds.contains(it.id)) {
        _selectedIds.remove(it.id);
      } else {
        _selectedIds.add(it.id);
      }
    });
  }

  Future<void> _showFolderOrgSheet(_OneShortItem it) async {
    final action = await showModalBottomSheet<String>(
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
            16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('Add to another collection'),
                onTap: () => Navigator.pop(ctx, 'add_other'),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('Remove from collection'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Multi Select'),
                subtitle: const Text('Select multiple items to organize.'),
                onTap: () => Navigator.pop(ctx, 'multi'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'multi') {
      setState(() {
        _selecting = true;
        _selectedIds.add(it.id);
      });
      return;
    }
    if (action == 'add_other') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add to another collection - Coming soon'),
        ),
      );
      return;
    }
    if (action == 'remove') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove from collection - Coming soon')),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.folder.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        leading: NimonBackButton(onPressed: () => Navigator.pop(context)),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StackedFolderThumb(items: widget.folder.items),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.folder.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.folder.items.length} ${widget.folder.items.length == 1 ? 'story' : 'stories'} · ${widget.isSavedSection ? 'Saved' : 'Published'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black.withOpacity(0.60),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_selecting) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} selected',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selecting = false;
                        _selectedIds.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Collection bulk actions - Coming soon',
                                  ),
                                ),
                              );
                            },
                      child: const Text('Organize'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No stories in this collection yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final it = items[i];
                final selected = _selectedIds.contains(it.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _selecting
                          ? () => _toggle(it)
                          : (widget.onStoryTap == null
                              ? null
                              : () => widget.onStoryTap!(
                                    widget.folder.items,
                                    widget.folder.items.indexOf(it),
                                  )),
                      onLongPress: () => _showFolderOrgSheet(it),
                      child: Stack(
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: selected ? 0.85 : 1.0,
                            child: MonoStoryListRow(
                              title: it.title,
                              description: it.description,
                              jlptLevel: it.jlptLevel,
                              thumbnailUrl: it.thumbnailUrl,
                              onMenuTap: () => _showFolderOrgSheet(it),
                            ),
                          ),
                          if (_selecting)
                            Positioned(
                              top: 8,
                              left: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: selected ? Colors.black : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.20),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Icon(
                                    selected
                                        ? Icons.check_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color:
                                        selected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Top header bar (plus • username ▼ • notifications + menu), matching the reference structure.
class _ProfileTopHeaderBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onNotifications;
  final VoidCallback onMenu;

  const _ProfileTopHeaderBar({
    required this.onAdd,
    required this.onNotifications,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_box_outlined),
            visualDensity: VisualDensity.compact,
            tooltip: 'Share profile',
          ),
          const Spacer(),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
            visualDensity: VisualDensity.compact,
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
            visualDensity: VisualDensity.compact,
            tooltip: 'Menu',
          ),
        ],
      ),
    );
  }
}

/// Owner header avatar — uses live public-profile URL when present (M9f).
class _OwnerProfileAvatar extends StatelessWidget {
  const _OwnerProfileAvatar({this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = (url ?? '').trim();
    final dim = radius * 2;
    if (u.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_rounded,
          size: radius * 0.87,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        u,
        width: dim,
        height: dim,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => Container(
          width: dim,
          height: dim,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            size: radius * 0.87,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Owner profile header: two-column block (avatar | name + handle + stats), then bio (M3).
class _ProfileSummaryRow extends StatelessWidget {
  final String displayName;
  final String handle;

  /// Public avatar from `GET /v1/users/:me/public-profile` after edit (M9f).
  final String? avatarUrl;

  /// Short line under the handle (e.g. role); omit when null/empty.
  final String? tagline;
  final String bio;
  final String uploadedCount;
  final String followersCount;
  final String followingCount;

  const _ProfileSummaryRow({
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    this.tagline,
    required this.bio,
    required this.uploadedCount,
    required this.followersCount,
    required this.followingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tag = (tagline ?? '').trim();
    final bioText = bio.trim();
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OwnerProfileAvatar(
                url: avatarUrl,
                radius: 46,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (handle.trim().isNotEmpty) ...[
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (tag.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tag,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStat(
                            value: uploadedCount,
                            label: 'Published',
                          ),
                        ),
                        _ProfileStatDivider(color: dividerColor),
                        Expanded(
                          child: _CompactStat(
                            value: followersCount,
                            label: 'Followers',
                            onTap: () => context.push('/profile/followers'),
                          ),
                        ),
                        _ProfileStatDivider(color: dividerColor),
                        Expanded(
                          child: _CompactStat(
                            value: followingCount,
                            label: 'Following',
                            onTap: () => context.push('/profile/following'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bioText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              bioText,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 34,
        width: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _CompactStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
      fontSize: 11,
      height: 1.15,
      letterSpacing: 0.1,
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            height: 1.05,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: labelStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    Widget centered(Widget w) => Center(child: w);

    if (onTap == null) {
      return centered(column);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: centered(column),
        ),
      ),
    );
  }
}

/// Opens the learner-facing public profile preview ([PublicProfileScreen]).
class _PublicProfilePreviewCard extends ConsumerWidget {
  const _PublicProfilePreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(authSessionProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (session is AuthSessionAuthenticated) {
              final id = Uri.encodeQueryComponent(session.user.id);
              context.push('/profile/public?from=owner&userId=$id');
            } else {
              context.push('/profile/public?from=owner');
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View public profile',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'See how other learners view your page',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab icons row with underline indicator (compact, minimal).
class _ProfileIconTabs extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onTap;

  const _ProfileIconTabs({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = Colors.black.withOpacity(0.45);

    Widget tab(
        {required int idx, required IconData icon, required String label}) {
      final selected = controller.index == idx;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(idx),
          child: SizedBox(
            height: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? ink : muted),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? ink : muted,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 26,
                  decoration: BoxDecoration(
                    color: selected ? ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            children: [
              Divider(height: 1, color: Colors.black.withOpacity(0.06)),
              Row(
                children: [
                  tab(
                    idx: 0,
                    icon: Icons.cloud_done_outlined,
                    label: 'Published',
                  ),
                  tab(idx: 1, icon: Icons.schedule_rounded, label: 'Workspace'),
                  tab(
                    idx: 2,
                    icon: Icons.bookmark_border_rounded,
                    label: 'Saved',
                  ),
                ],
              ),
              Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            ],
          );
        },
      ),
    );
  }
}

/// Published / Processing / Saved — equal-width segments (syncs with [TabController] + [PageView]).
// (Removed old segmented tabs + header widgets; replaced by reference-aligned layout.)

class _OneShortList extends StatelessWidget {
  final List<_OneShortItem> items;
  final double bottomPadding;
  final _OneShortCardAction trailingAction;
  final void Function(_OneShortItem item)? onItemTap;

  const _OneShortList({
    required this.items,
    required this.bottomPadding,
    this.trailingAction = _OneShortCardAction.edit,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ProcessingSelectableList(
      items: items,
      bottomPadding: bottomPadding,
      trailingAction: trailingAction,
      onOpenDetail: onItemTap,
      onDeleteSelected: (_) {
        // V1: processing drafts are already manageable item-by-item via the detail sheet.
        // Bulk delete can be added later when real data + selection toolbar exists.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Multi-select delete - Coming soon')),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Processing: local draft manager (V1)
// -----------------------------------------------------------------------------

enum _WorkspaceState {
  draft,
  editing,
}

/// Maps API/summary [DraftListSummaryDto.publishState] to domain enum.
StoryPublishState publishStateFromDraftSummaryKey(String key) {
  switch (key.trim()) {
    case 'reading_only_published':
      return StoryPublishState.readingOnlyPublished;
    case 'full_learn_published':
      return StoryPublishState.fullLearnPublished;
    default:
      return StoryPublishState.draft;
  }
}

/// Draft vs Editing chip for rows shown in Workspace (synced summaries are filtered out).
_WorkspaceState workspaceStateFromDraftSummary(DraftListSummaryDto s) {
  return effectiveDraftListWorkspaceState(s) == 'editing'
      ? _WorkspaceState.editing
      : _WorkspaceState.draft;
}

class _ProcessingDraftItem {
  /// Workspace index row — avoid loading full [CreatorStoryV1] for display.
  final DraftListSummaryDto summary;

  /// Resolved from [summary.publishState] for resume / buttons.
  final StoryPublishState resolvedPublishState;

  /// Workspace classification (Draft vs Editing) derived from summary only.
  final _WorkspaceState workspaceState;
  final String title;
  final String preview;
  final String level;
  final String category;
  final String durationLabel;
  final DateTime updatedAt;

  const _ProcessingDraftItem({
    required this.summary,
    required this.resolvedPublishState,
    required this.workspaceState,
    required this.title,
    required this.preview,
    required this.level,
    required this.category,
    required this.durationLabel,
    required this.updatedAt,
  });

  String get draftId => summary.draftId.trim();

  factory _ProcessingDraftItem.fromSummary(DraftListSummaryDto s) {
    final ps = publishStateFromDraftSummaryKey(s.publishState);
    final ws = workspaceStateFromDraftSummary(s);
    final title = s.title.trim().isEmpty ? 'Untitled draft' : s.title.trim();
    final preview = (s.previewText != null && s.previewText!.trim().isNotEmpty)
        ? s.previewText!.trim()
        : 'Continue editing your draft';
    final level = s.level.trim().isEmpty ? '—' : s.level.trim();
    final category = s.category.trim().isEmpty ? '—' : s.category.trim();
    var updatedAt = DateTime.tryParse(s.updatedAt ?? '');
    updatedAt ??= DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return _ProcessingDraftItem(
      summary: s,
      resolvedPublishState: ps,
      workspaceState: ws,
      title: title,
      preview: preview,
      level: level,
      category: category,
      durationLabel: CreatorProcessingCopy.draftSummaryDurationChip(
        s.targetDurationBandKey,
      ),
      updatedAt: updatedAt,
    );
  }
}

class _ProcessingDraftManagerTab extends StatefulWidget {
  const _ProcessingDraftManagerTab({
    required this.items,
    required this.pagerState,
    required this.highlightDraftId,
    required this.bottomPadding,
    required this.onChanged,
    this.onNearEnd,
  });

  final List<_ProcessingDraftItem> items;
  final PaginatedState<DraftListSummaryDto> pagerState;
  final String? highlightDraftId;
  final double bottomPadding;
  final VoidCallback onChanged;
  final VoidCallback? onNearEnd;

  @override
  State<_ProcessingDraftManagerTab> createState() =>
      _ProcessingDraftManagerTabState();
}

class _ProcessingDraftManagerTabState
    extends State<_ProcessingDraftManagerTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  /// Stable signature for list identity: publish state moves, sort order, and timestamps.
  static String _itemsLayoutSignature(List<_ProcessingDraftItem> items) {
    final sorted = List<_ProcessingDraftItem>.from(items)
      ..sort((a, b) => a.draftId.compareTo(b.draftId));
    final buf = StringBuffer();
    for (final e in sorted) {
      buf
        ..write(e.draftId)
        ..write(':')
        ..write(e.resolvedPublishState.index)
        ..write(':')
        ..write(e.updatedAt.microsecondsSinceEpoch)
        ..write('|');
    }
    return buf.toString();
  }

  void _pruneCardKeysForCurrentItems() {
    final valid = widget.items.map((e) => e.draftId).toSet();
    _cardKeys.removeWhere((id, _) => !valid.contains(id));
  }

  /// Target must be in the tree, painted, and under a [Scrollable] before [Scrollable.ensureVisible]
  /// (avoids web-only `_elements.contains(element)` during post-frame vs layout races).
  static bool _contextSafeForEnsureVisible(BuildContext ctx) {
    if (!ctx.mounted) return false;
    final ro = ctx.findRenderObject();
    if (ro == null || !ro.attached) return false;
    return Scrollable.maybeOf(ctx) != null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightIfNeeded({int attempt = 0}) {
    if (!mounted) return;
    final id = widget.highlightDraftId;
    if (id == null || id.isEmpty) return;
    if (!widget.items.any((e) => e.draftId == id)) return;

    final ctx = _keyFor(id).currentContext;
    if (ctx == null || !_contextSafeForEnsureVisible(ctx)) {
      if (attempt < 2 &&
          mounted &&
          (widget.highlightDraftId ?? '').isNotEmpty &&
          widget.items.any((e) => e.draftId == id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToHighlightIfNeeded(attempt: attempt + 1);
        });
      }
      return;
    }

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _pruneCardKeysForCurrentItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToHighlightIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant _ProcessingDraftManagerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layoutChanged = _itemsLayoutSignature(widget.items) !=
        _itemsLayoutSignature(oldWidget.items);
    if (widget.highlightDraftId != oldWidget.highlightDraftId ||
        layoutChanged) {
      _pruneCardKeysForCurrentItems();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToHighlightIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final drafts = <_ProcessingDraftItem>[];
    final editing = <_ProcessingDraftItem>[];

    for (final it in widget.items) {
      // Workspace contains only:
      // - Draft: never published.
      // - Editing: previously published (see [workspaceStateFromDraftSummary] limitations).
      if (it.workspaceState == _WorkspaceState.editing) {
        editing.add(it);
      } else if (it.resolvedPublishState == StoryPublishState.draft) {
        drafts.add(it);
      }
    }

    void sortByUpdated(List<_ProcessingDraftItem> list) {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    sortByUpdated(drafts);
    sortByUpdated(editing);

    final draftCount = drafts.length;
    final editingCount = editing.length;

    if (widget.items.isEmpty) {
      if (widget.pagerState.isInitialLoading &&
          widget.pagerState.error == null) {
        return ColoredBox(
          color: const Color(0xFFF5F5F5),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: const CircularProgressIndicator(),
            ),
          ),
        );
      }
      return ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, widget.bottomPadding),
          children: [
            Card(
              elevation: 0,
              color: cs.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side:
                    BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.schedule_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nothing in Processing yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Local drafts and stories you publish (Read Only or Full Learn) appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ProviderScope.containerOf(context, listen: false)
                            .read(creatorEntryChannelProvider.notifier)
                            .state = CreatorEntryChannel.shellMore;
                        context.push('/create');
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Start new story'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final dividerColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28);

    Widget section(String title, List<_ProcessingDraftItem> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProcessingSectionHeader(title: title),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: dividerColor,
              ),
            Padding(
              key: _keyFor(items[i].draftId),
              padding: EdgeInsets.zero,
              child: _ProcessingDraftCard(
                item: items[i],
                pulseHighlight: widget.highlightDraftId == items[i].draftId,
                onChanged: widget.onChanged,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      );
    }

    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          final m = n.metrics;
          if (m.maxScrollExtent <= 0) return false;
          if (m.pixels >= m.maxScrollExtent * 0.72) {
            widget.onNearEnd?.call();
          }
          return false;
        },
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, 14, 16, widget.bottomPadding),
          children: [
            _WorkspaceSummaryBar(
              draftCount: draftCount,
              editingCount: editingCount,
            ),
            const SizedBox(height: 14),
            if (drafts.isNotEmpty) section('Drafts', drafts),
            if (editing.isNotEmpty) section('Editing', editing),
            if (widget.pagerState.isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSummaryBar extends StatelessWidget {
  const _WorkspaceSummaryBar({
    required this.draftCount,
    required this.editingCount,
  });

  final int draftCount;
  final int editingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget pill(String label, int value) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  height: 1.0,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  height: 1.0,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        pill('Draft', draftCount),
        pill('Editing', editingCount),
      ],
    );
  }
}

class _ProcessingSectionHeader extends StatelessWidget {
  const _ProcessingSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.black.withOpacity(0.55),
          height: 1.0,
        ),
      ),
    );
  }
}

/// Lightweight list row for Profile > Processing (not a boxed card): soft tap
/// target, dividers from parent, small thumbnail, status line, chips, primary
/// affordance + overflow.
class _ProcessingDraftCard extends ConsumerWidget {
  const _ProcessingDraftCard({
    super.key,
    required this.item,
    required this.pulseHighlight,
    required this.onChanged,
  });

  final _ProcessingDraftItem item;
  final bool pulseHighlight;
  final VoidCallback onChanged;

  String _updatedLabel() {
    final dt = item.updatedAt.toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $hh:$mm';
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: item.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename draft'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Draft title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final title = (next ?? '').trim();
    if (title.isEmpty || title == item.title) return;

    final repo = ref.read(storyDraftRepositoryProvider);
    final loaded = await repo.loadDraft(item.draftId);
    if (!context.mounted) return;
    if (loaded == null) return;
    final updated = loaded.copyWith(
      basics: loaded.basics.copyWith(title: title),
    );
    final saved = await repo.saveDraft(updated);
    if (!context.mounted) return;
    ref
        .read(storyCreatorDraftProvider.notifier)
        .syncIfSameDraftWasPersistedElsewhere(saved);
    onChanged();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete local draft?'),
        content: Text('Delete “${item.title}” from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDF3B3B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (ok != true) return;
    await ref.read(storyDraftRepositoryProvider).deleteDraft(item.draftId);
    if (!context.mounted) return;
    ref
        .read(storyCreatorDraftProvider.notifier)
        .syncIfDraftWasRemovedExternally(item.draftId);
    ref
        .read(profileWorkspaceDraftPagerProvider.notifier)
        .removeDraftById(item.draftId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final secondary = item.preview.trim().isNotEmpty
        ? item.preview
        : CreatorProcessingCopy.secondaryLineSummaryOnly(
            item.resolvedPublishState,
          );
    final actionLabel =
        CreatorProcessingCopy.primaryButton(item.resolvedPublishState);

    final statusChip = switch (item.workspaceState) {
      _WorkspaceState.draft => const _ProcessingChip(
          label: 'Draft',
          background: Color(0xFFDF3B3B),
          foreground: Colors.white,
          border: Color(0xFFDF3B3B),
        ),
      _WorkspaceState.editing => const _ProcessingChip(
          label: 'Editing • Previously published',
          background: Color(0xFF2F6FED),
          foreground: Colors.white,
          border: Color(0xFF2F6FED),
        ),
    };

    void onResume() => unawaited(
          CreatorDraftResumeFlow.resumeFromProcessing(
            context,
            item.draftId,
            publishState: item.resolvedPublishState,
          ),
        );

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onResume,
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            pulseHighlight ? 8 : 12,
            8,
            4,
            8,
          ),
          decoration: BoxDecoration(
            color: pulseHighlight
                ? cs.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            border: pulseHighlight
                ? Border(
                    left: BorderSide(
                      color: cs.primary.withValues(alpha: 0.75),
                      width: 3,
                    ),
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProcessingThumb(title: item.title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        height: 1.15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        statusChip,
                        _ProcessingChip(label: item.level),
                        _ProcessingChip(label: item.category),
                        _ProcessingChip(label: item.durationLabel),
                        if (item.summary.sentenceCount > 0)
                          _ProcessingChip(
                            label: '${item.summary.sentenceCount} sentences',
                          ),
                        _ProcessingChip(label: 'Updated ${_updatedLabel()}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton<String>(
                      tooltip: 'Story actions',
                      onSelected: (v) {
                        if (v == 'rename') unawaited(_rename(context, ref));
                        if (v == 'delete') unawaited(_delete(context, ref));
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete from this device'),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _ProcessingActionButton(
                    label: actionLabel,
                    onTap: onResume,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return row;
  }
}

/// Tiny letter-avatar thumbnail used by Processing rows.
///
/// Drafts don't carry an image yet; this gives each row a stable, scannable
/// left anchor while keeping the row low-bulk.
class _ProcessingThumb extends StatelessWidget {
  const _ProcessingThumb({required this.title});

  final String title;

  static String _initialFor(String s) {
    final t = s.trim();
    if (t.isEmpty) return '·';
    final r = t.runes.first;
    return String.fromCharCode(r).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Text(
            _initialFor(title),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.78),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary next-step control — text + chevron (lighter than a filled pill; still obvious).
class _ProcessingActionButton extends StatelessWidget {
  const _ProcessingActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}

/// Tiny meta chip (level / category / duration / updated).
///
/// Smaller, lighter than the previous pill so a row can show 4+ without
/// inflating height.
class _ProcessingChip extends StatelessWidget {
  const _ProcessingChip({
    required this.label,
    this.background,
    this.foreground,
    this.border,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? cs.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: border ?? cs.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: foreground ?? cs.onSurface.withValues(alpha: 0.78),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ProcessingSelectableList extends StatefulWidget {
  const _ProcessingSelectableList({
    required this.items,
    required this.bottomPadding,
    required this.trailingAction,
    required this.onOpenDetail,
    required this.onDeleteSelected,
  });

  final List<_OneShortItem> items;
  final double bottomPadding;
  final _OneShortCardAction trailingAction;
  final void Function(_OneShortItem item)? onOpenDetail;
  final void Function(Set<String> ids) onDeleteSelected;

  @override
  State<_ProcessingSelectableList> createState() =>
      _ProcessingSelectableListState();
}

class _ProcessingSelectableListState extends State<_ProcessingSelectableList> {
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};

  void _toggle(_OneShortItem it) {
    setState(() {
      if (_selectedIds.contains(it.id)) {
        _selectedIds.remove(it.id);
      } else {
        _selectedIds.add(it.id);
      }
    });
  }

  Future<void> _showOrgSheet(_OneShortItem it) async {
    final action = await showModalBottomSheet<String>(
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
            16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Multi Select'),
                subtitle: const Text('Select multiple items, then delete.'),
                onTap: () => Navigator.pop(ctx, 'multi'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'multi') {
      setState(() {
        _selecting = true;
        _selectedIds.add(it.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
        itemCount: widget.items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0 && _selecting) {
            final count = _selectedIds.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count selected',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selecting = false;
                          _selectedIds.clear();
                        }),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: count == 0
                            ? null
                            : () {
                                widget.onDeleteSelected(
                                  Set<String>.from(_selectedIds),
                                );
                                setState(() {
                                  _selecting = false;
                                  _selectedIds.clear();
                                });
                              },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final i = index - 1;
          if (i < 0) return const SizedBox.shrink();
          final it = widget.items[i];
          final selected = _selectedIds.contains(it.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _selecting
                    ? () => _toggle(it)
                    : (widget.onOpenDetail == null
                        ? null
                        : () => widget.onOpenDetail!(it)),
                onLongPress: () => _showOrgSheet(it),
                child: Stack(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: selected ? 0.85 : 1.0,
                      child: MonoStoryListRow(
                        title: it.title,
                        description: it.description,
                        jlptLevel: it.jlptLevel,
                        thumbnailUrl: it.thumbnailUrl,
                        onMenuTap: () => _showOrgSheet(it),
                      ),
                    ),
                    if (_selecting)
                      Positioned(
                        top: 8,
                        left: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.20)),
                          ),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryCoverThumb extends StatelessWidget {
  final String? thumbnailUrl;
  final String jlptLevel;
  final double size;
  final double borderRadius;
  final bool denseBadge;

  const _StoryCoverThumb({
    required this.thumbnailUrl,
    required this.jlptLevel,
    required this.size,
    required this.borderRadius,
    this.denseBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasThumb = (thumbnailUrl ?? '').trim().isNotEmpty;
    final r = BorderRadius.circular(borderRadius);

    Widget image() {
      if (hasThumb) {
        return Image.network(
          thumbnailUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.image_outlined,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
        );
      }
      return ColoredBox(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.image_outlined,
          color: Colors.black.withOpacity(0.35),
        ),
      );
    }

    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image(),
            Positioned(
              top: denseBadge ? 4 : 8,
              left: denseBadge ? 4 : 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: denseBadge ? 6 : 8,
                    vertical: denseBadge ? 3 : 4,
                  ),
                  child: Text(
                    jlptLevel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: denseBadge ? 10 : 11,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
