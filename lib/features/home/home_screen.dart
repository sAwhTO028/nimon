import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import '../../data/story_repo.dart';
import '../../models/story.dart';
import '../../models/episode_meta.dart';
import '../../models/section_key.dart';
import '../../ui/widgets/sheets/show_episode_modal.dart';
import 'widgets/mono_collection_row.dart';
import 'widgets/book_cover_card.dart';
import 'widgets/community_section.dart';
import 'widgets/trending_for_you.dart';
import 'widgets/premium_banner.dart';
import 'widgets/section_header.dart';
import 'sections/reading_challenges_section.dart';
import 'sections/quick_one_shot_section.dart';
import 'data/challenges.dart';

class HomeScreen extends StatefulWidget {
  final StoryRepo repo;
  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _StoryTab { premium, newRelease }

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late Future<List<Story>> _future;
  late Future<List<Story>> _featuredFuture;
  late Future<List<Story>> _latestFuture;
  String _rank = 'ALL';
  String _category = 'ALL';
  _StoryTab _tab = _StoryTab.premium;
  final _ranks = const ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'];
  final _categories = const [
    'ALL',
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery',
  ];

  StoryRepo get repo => widget.repo;

  // Data helpers for premium/new release
  List<Story> _premiumStories = [];
  List<Story> _newReleaseStories = [];

  // Tab controller for tabs
  late TabController _tabController;
  late PageController _pageController;

  void _updateStoryLists(List<Story> stories) {
    _premiumStories = stories.take(5).toList();
    _newReleaseStories = stories.skip(2).take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _future = repo.listStories();
    
    // Preload both tab futures immediately with different data sources
    _featuredFuture = repo.getStories(rank: 'N5'); // Featured stories (N5 level)
    _latestFuture = repo.getStories(rank: 'N4'); // Latest releases (N4 level)
    
    // Initialize controllers
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _pageController = PageController(initialPage: 0);
    
    // Keep TabBar in sync when user swipes pages
    _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_tabController.index != newIndex) {
        _tabController.animateTo(newIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openBestEpisode(BuildContext context, Story s) async {
    // 1) show loader
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final eps = await repo.getEpisodesByStory(s.id);

      if (!context.mounted) return;

      // 2) close loader BEFORE pushing
      Navigator.of(context, rootNavigator: true).pop();

      if (eps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No episodes yet')),
        );
        return;
      }

      // 3) pick best (latest)
      eps.sort((a, b) => b.index.compareTo(a.index));
      final best = eps.first;

      // small delay so the pop animation fully finishes
      await Future.delayed(const Duration(milliseconds: 80));
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderScreen(episode: best)),
      );
    } catch (e) {
      if (!context.mounted) return;
      // ensure loader is closed on error
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open episode: $e')),
      );
    }
  }

  Future<void> _openEpisode(BuildContext context, Episode episode) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(episode: episode)),
    );
  }

  Future<List<Episode>> _getPopularEpisodes() async {
    final stories = await _future;
    final popularStories =
        stories.take(5).toList(); // Get top 5 popular stories
    final List<Episode> allEpisodes = [];

    for (final story in popularStories) {
      try {
        final episodes = await repo.getEpisodesByStory(story.id);
        allEpisodes.addAll(episodes);
      } catch (e) {
        // Continue with other stories if one fails
        continue;
      }
    }

    // Sort by index and take the first 8 episodes
    allEpisodes.sort((a, b) => b.index.compareTo(a.index));
    return allEpisodes.take(8).toList();
  }

  Future<List<Episode>> _getNewWritersEpisodes() async {
    final stories = await _future;
    // Get stories from index 5-9 (different from popular stories) to simulate new writers
    final newWritersStories = stories.skip(5).take(5).toList();
    final List<Episode> allEpisodes = [];

    for (final story in newWritersStories) {
      try {
        final episodes = await repo.getEpisodesByStory(story.id);
        allEpisodes.addAll(episodes);
      } catch (e) {
        // Continue with other stories if one fails
        continue;
      }
    }

    // Sort by index and take the first 8 episodes
    allEpisodes.sort((a, b) => b.index.compareTo(a.index));
    return allEpisodes.take(8).toList();
  }

  List<Episode> _getContinueReadingEpisodes() {
    // Demo content - return 3 episodes for continue reading
    // In a real app, this would be episodes the user has started reading
    return [
      Episode(
        id: 'continue_ep_1',
        storyId: 'continue_1',
        index: 3,
        blocks: [
          EpisodeBlock(
            type: BlockType.narration,
            text: 'The rain continued to fall on the ancient streets of Kyoto...',
          ),
        ],
      ),
      Episode(
        id: 'continue_ep_2',
        storyId: 'continue_2',
        index: 5,
        blocks: [
          EpisodeBlock(
            type: BlockType.narration,
            text: 'As they climbed higher into the mountains, the air grew thinner...',
          ),
        ],
      ),
      Episode(
        id: 'continue_ep_3',
        storyId: 'continue_3',
        index: 2,
        blocks: [
          EpisodeBlock(
            type: BlockType.narration,
            text: 'The city lights twinkled like stars in the urban night...',
          ),
        ],
      ),
    ];
  }

  // Removed _getCommunityCollections() - now using CommunitySection widget with real data

  void _onSelectRank(String v) {
    setState(() {
      _rank = v;
      _reload();
    });
  }

  void _onSelectCategory(String v) {
    setState(() {
      _category = v;
      _reload();
    });
  }

  void _reload() {
    if (_rank == 'ALL' && _category == 'ALL') {
      _future = repo.getStories();
    } else if (_rank != 'ALL' && _category == 'ALL') {
      _future = repo.getStories(rank: _rank);
    } else if (_rank == 'ALL' && _category != 'ALL') {
      _future = repo.getStories(category: _category);
    } else {
      _future = repo.getStories(rank: _rank, category: _category);
    }
  }

  Widget _rankRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _ranks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final v = _ranks[i];
          final selected = _rank == v;
          return ChoiceChip(
            label: Text(v),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _rank = v;
              });
              _reload();
            },
          );
        },
      ),
    );
  }

  Widget _categoryRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final v = _categories[i];
          final selected = _category == v;
          return ChoiceChip(
            label: Text(v),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _category = v;
              });
              _reload();
            },
          );
        },
      ),
    );
  }

  void _openDetail(Story s) {
    context.push('/story/${s.id}');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
              // Header with title and balance
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text('NIMON',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 28,
                                letterSpacing: 0.5,
                              )),
                  const Spacer(),
                  _balancePill('\$ 98'),
                ],
              ),
            ),
          ),

              // Rank and Category filters
          SliverToBoxAdapter(child: _rankRow()),
          SliverToBoxAdapter(child: _categoryRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 1) Continue Reading section
              SliverToBoxAdapter(child: _continueReadingSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 2) Recommend Stories section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recommend Stories',
                  sectionKey: SectionKey.recommendStories,
                  storyRepo: widget.repo,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: FutureBuilder<List<Story>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()));
                }
                final stories = snap.data ?? const <Story>[];
                _updateStoryLists(stories);
                return SizedBox(
                  height: 140 * 3 / 2, // Calculate height from BookCoverCard.md width and aspect ratio
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (ctx, i) {
                      final s = stories[i];
                      return BookCoverCard.md(
                        story: s,
                        onTap: () => _openDetail(s),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // PREMIUM HIGHLIGHT BANNER
              SliverToBoxAdapter(
                child: PremiumBanner(
                  onTap: () {
                    // TODO: navigate to Premium / Paywall (leave as is if route not ready)
                    // context.push('/premium');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Premium upgrade coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),


          // 3) From the Community section
          SliverToBoxAdapter(
            child: CommunitySection(
              repo: repo,
              onSeeAllTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('See all community collections coming soon!'),
                    action: SnackBarAction(
                      label: 'OK',
                      onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 4) Quick One-Shot For You section
          SliverToBoxAdapter(
            child: QuickOneShotSection(storyRepo: widget.repo),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 3) Popular Mono writer's collections
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF8F9FA), // Subtle neutral shade
              child: Column(
                children: [
                  SectionHeader(
                    title: "Popular Episode Co-Writer's Collections",
                    sectionKey: SectionKey.popularMonoCollections,
                    storyRepo: widget.repo,
                    showSeeAll: false,
                  ),
                      const SizedBox(height: 16),
                  FutureBuilder<List<Episode>>(
                    future: _getPopularEpisodes(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      final episodes = snap.data!;
                      return MonoCollectionRow(
                        episodes: episodes,
                        title: 'Popular Episode\nCo-Writer\'s Collections',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

              // 4) New Writers Spotlight
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white, // Clean white background
              margin: const EdgeInsets.only(bottom: 0), // No extra bottom margin
              child: Column(
                children: [
                  SectionHeader(
                    title: "New Writers Spotlight",
                    sectionKey: SectionKey.newWritersSpotlight,
                    storyRepo: widget.repo,
                    showSeeAll: false,
                  ),
                      const SizedBox(height: 16),
                  FutureBuilder<List<Episode>>(
                    future: _getNewWritersEpisodes(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      final episodes = snap.data!;
                      return MonoCollectionRow(
                        episodes: episodes,
                        title: 'New Writers\nSpotlight',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

              // Guaranteed spacing from previous section
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Top Charts header (isolated)
          SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Top Charts',
                  sectionKey: SectionKey.topCharts,
                  storyRepo: widget.repo,
                ),
              ),

              // TabBar with proper spacing
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (i) => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      insets: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Featured Stories'),
                      Tab(text: 'Latest Releases'),
                    ],
                  ),
                ),
              ),

              // Spacing from TabBar to first list item
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // PageView with fixed height (no inner scrolling)
              SliverToBoxAdapter(
                child: _topChartsContent(context),
              ),
              
              // Trending For You section
              SliverToBoxAdapter(
                child: FutureBuilder<List<Story>>(
                  future: _future,
                  builder: (ctx, snap) {
                    if (snap.hasData) {
                      return TrendingForYou(
                        stories: snap.data!.take(5).toList(),
                        storyRepo: widget.repo,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              
              // Reading Challenges (the last one)
              SliverToBoxAdapter(
                child: ReadingChallengesSection(
                  onSelect: (c) {
                    // TODO: hook to your filtering / discovery route.
                    // Example (adapt to your router):
                    // context.push('/discover?category=${Uri.encodeComponent(c.title)}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${c.title} challenge selected!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              
              // tiny bottom space only
              SliverToBoxAdapter(child: SizedBox(height: pad + 16)),
            ],
          ),
        ),
      );
  }

  // ───────────────────────── widgets ─────────────────────────

  // Top Charts content with PageView and fixed height
  Widget _topChartsContent(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    const rowH = 96.0;   // height of one compact row
    const gap = 12.0;    // space between rows
    const maxCount = 5;  // maximum rows to show
    final contentHeight = (rowH * maxCount) + (gap * (maxCount - 1)) + 16 + bottom;

    return SizedBox(
      height: contentHeight,
      child: PageView(
        controller: _pageController,
        onPageChanged: (i) => _tabController.animateTo(i),
        children: [
          FutureBuilder<List<Story>>(
            future: _featuredFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final stories = snapshot.data ?? <Story>[];
              return _TopChartFixed(items: stories);
            },
          ),
          FutureBuilder<List<Story>>(
            future: _latestFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final stories = snapshot.data ?? <Story>[];
              return _TopChartFixed(items: stories);
            },
          ),
        ],
      ),
    );
  }

  // Top Charts list widget with proper bottom padding
  Widget _TopChartList({required List<Story> items}) {
    return _TopChartListWidget(items: items);
  }

  Widget _coinBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: const [
          Icon(Icons.attach_money, size: 18),
          SizedBox(width: 6),
          Text('98', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _balancePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Text(
        text, 
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }


  Widget _continueReadingSection() {
    final episodes = _getContinueReadingEpisodes();
    
    // Hide section if no episodes
    if (episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        SectionHeader(
          title: 'Continue Reading',
          sectionKey: SectionKey.continueReading,
          storyRepo: widget.repo,
        ),
        const SizedBox(height: 16),
        // Horizontal List
        SizedBox(
          height: 200, // Reduced height for better proportion
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];
              return _buildEpisodeCard(context, episode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeCard(BuildContext context, Episode episode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Placeholder metadata since Episode doesn't link Story details directly
    const defaultCategory = 'Love';
    const jlpt = 'N5';
    const writer = 'WRITER NAME';
    const likes = 4200;
    final cover = 'https://images.unsplash.com/photo-1519638399535-1b036603ac77?w=800';

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // Show episode bottom sheet with sample data
          final episodeMeta = EpisodeMeta(
            id: episode.id,
            title: episode.title ?? 'Sample Story Title',
            episodeNo: 'Episode ${episode.index}',
            authorName: writer,
            coverUrl: cover,
            jlpt: jlpt,
            likes: likes,
            readTime: '5 min',
            category: defaultCategory,
            preview: episode.preview.isNotEmpty 
                ? episode.preview 
                : 'Rain was falling softly in Kyoto. Aya stood under her umbrella. (Ep ${episode.index})',
          );
          
          showEpisodeModalFromMeta(
            context,
            episodeMeta,
            onSave: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved for later!')),
              );
            },
            onStartReading: () {
              // Navigate to reader
              _openEpisode(context, episode);
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image area with overlays
              Expanded(
                flex: 71,
                child: Stack(
                  children: [
                    // Cover image - fills entire image space
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        cover,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(context),
                      ),
                    ),
                    
                    // Top-left badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildTypeBadge(context, 'Episode'),
                    ),
                    
                    // Top-right JLPT chip
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildJLPTChip(context, jlpt),
                    ),
                    
                    // Blur title band overlay
                    _buildTitleBandWithBlur(context, episode),
                  ],
                ),
              ),
              
              // Footer/Base Card
              Expanded(
                flex: 25,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Writer avatar
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          writer.isNotEmpty ? writer[0].toUpperCase() : 'W',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      
                      // Writer info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              writer,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Episode ${episode.index}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.short_text_rounded,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJLPTChip(BuildContext context, String jlpt) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          jlpt,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildTitleBandWithBlur(BuildContext context, Episode episode) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Positioned(
      bottom: 10,
      left: 12,
      right: 12,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.3),
              ),
              child: Center(
                child: Text(
                  episode.title ?? 'Episode ${episode.index}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _heroCard(BuildContext context, int i) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.network(
            // demo images
            'https://picsum.photos/seed/banner$i/640/360',
            width: 300,
            height: 180,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Banner #${i + 1}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyThumb(BuildContext context, Story s) {
    final w = 300.0;
    return GestureDetector(
      onTap: () => _openDetail(s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.network(
              (s.coverUrl?.isNotEmpty ?? false)
                  ? s.coverUrl!
                  : 'https://picsum.photos/seed/${s.id}/640/360',
              width: w,
              height: 180,
              fit: BoxFit.cover,
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  s.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(BuildContext context, String text, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }



  // Removed _fromTheCommunitySection() - now using CommunitySection widget

  Widget _buildSeeMoreCard(BuildContext context) {
    return SizedBox(
      width: 300, // Same width as story cards
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to see more stories
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('See more stories coming soon!'),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
      children: [
                // Icon
        Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
                ),
                const SizedBox(height: 16),
                
                // Text content
                Text(
                  'See More Stories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover more stories and adventures',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// Top Charts list widget with proper bottom padding
class _TopChartListWidget extends StatelessWidget {
  final List<Story> items;
  
  _TopChartListWidget({required this.items});
  
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final navH = kBottomNavigationBarHeight;
    final bottomPadding = bottom + navH + 16;
    
    final displayItems = items.take(5).toList(); // Show only 5 items
    
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding), // Safe bottom padding
      itemCount: displayItems.length + (items.length > 5 ? 1 : 0), // +1 for See More button
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        thickness: 0.5,
      ),
           itemBuilder: (context, index) {
        if (index >= displayItems.length) {
          // See More button
          return _buildSeeMoreButton(context);
        }
        
             final s = displayItems[index];
             final episodeCount = 8 + index; // placeholder
             final desc = (s.description?.isNotEmpty == true)
                 ? s.description!
                 : 'Description Description Description Description Description Description Description';

             return Container(
          decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
                 child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                // Navigate to story detail
                context.push('/story/${s.id}');
              },
                   child: Padding(
                padding: const EdgeInsets.all(12),
                     child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                    // Compact book cover thumbnail (72-76dp width, 2:3 ratio)
                    Container(
                      width: 72,
                      height: 108, // 2:3 aspect ratio (72 * 1.5)
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                           child: Image.network(
                          s.coverUrl ?? 'https://picsum.photos/seed/${s.id}/600/900',
                             fit: BoxFit.cover,
                             loadingBuilder: (context, child, loadingProgress) {
                               if (loadingProgress == null) return child;
                               return Container(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                                 child: const Center(
                                   child: CircularProgressIndicator(strokeWidth: 2),
                                 ),
                               );
                             },
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: const Center(
                                child: Icon(Icons.book, size: 24, color: Colors.grey),
                              ),
                               );
                             },
                           ),
                         ),
                    ),
                    const SizedBox(width: 12),

                    // Title and description
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Text(
                                 s.title,
                                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  height: 1.2,
                                     ),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                            softWrap: false,
                               ),
                          const SizedBox(height: 4),
                               Text(
                                 desc,
                                 maxLines: 2,
                                 overflow: TextOverflow.ellipsis,
                                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.2,
                                 ),
                               ),
            ],
          ),
        ),

                    const SizedBox(width: 12),

                         // Episode count
                         Text(
                           '$episodeCount Episodes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                 color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                               ),
                      textAlign: TextAlign.right,
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
             );
           },
    );
  }
  
  Widget _buildSeeMoreButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('See more stories coming soon!'),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See More',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTabName(_StoryTab tab) {
    switch (tab) {
      case _StoryTab.premium:
        return 'Featured Stories';
      case _StoryTab.newRelease:
        return 'Latest Releases';
    }
  }
}


// See All button widget
class SeeAllButton extends StatelessWidget {
  final VoidCallback? onTap;
  
  const SeeAllButton({Key? key, this.onTap}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('See all Top Charts coming soon!'),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
      children: [
                Text(
                  'See all',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fixed Top Chart widget showing exactly 5 rows without scrolling
class _TopChartFixed extends StatelessWidget {
  final List<Story> items;
  
  _TopChartFixed({required this.items});
  
  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            _TopChartRow(story: visible[i], episodeCount: 8 + i),
            if (i != visible.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 16), // breathing space above bottom nav
        ],
      ),
    );
  }
}

// Individual Top Chart row widget with compact design
class _TopChartRow extends StatelessWidget {
  final Story story;
  final int episodeCount;
  
  _TopChartRow({
    required this.story,
    required this.episodeCount,
  });
  
  @override
  Widget build(BuildContext context) {
    final desc = (story.description?.isNotEmpty == true)
        ? story.description!
        : 'Description Description Description Description Description Description Description';

    return Container(
      height: 96, // Fixed height for compact row
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to story detail
            context.push('/story/${story.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact book cover thumbnail (2:3 ratio, 76x114)
                Container(
                  width: 76,
                  height: 114,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      story.coverUrl ?? 'https://picsum.photos/seed/${story.id}/600/900',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const Center(
                            child: Icon(Icons.book, size: 24, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        story.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Episode count
                Text(
                  '$episodeCount Episodes',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
