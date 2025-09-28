import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import '../../data/story_repo.dart';
import '../../models/story.dart';
import 'widgets/mono_collection_row.dart';
import 'widgets/book_cover_card.dart';

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
  final _categories = const ['ALL', 'Love', 'Comedy', 'Horror', 'Drama'];

  StoryRepo get repo => widget.repo;

  // Data helpers for premium/new release
  List<Story> _premiumStories = [];
  List<Story> _newReleaseStories = [];

  // Tab controller for tabs
  late TabController _tabController;

  void _updateStoryLists(List<Story> stories) {
    _premiumStories = stories.take(5).toList();
    _newReleaseStories = stories.skip(2).take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _future = repo.listStories();
    
    // Preload both tab futures immediately
    _featuredFuture = repo.listStories(); // Featured stories
    _latestFuture = repo.listStories(); // Latest releases
    
    // Initialize controllers
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    
    // Sync tab controller with TabBarView
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _tab = _tabController.index == 0 ? _StoryTab.premium : _StoryTab.newRelease;
        });
      }
    });
  }

  @override
  void dispose() {
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: true,
          child: NestedScrollView(
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
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
              SliverToBoxAdapter(child: _sectionTitle(context, 'Recommend Stories')),
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

              // 3) Popular Mono writer's collections
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF8F9FA), // Subtle neutral shade
              child: Column(
                children: [
                  _sectionTitle(context, "Popular Mono writer's collections"),
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
                        title: 'Popular Mono\nCollections',
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
                  _sectionTitle(context, "New Writers Spotlight"),
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
                  trailing: const SeeAllButton(),
                ),
              ),

              // TabBar with proper spacing
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
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

              // TabBarView content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  physics: const PageScrollPhysics(), // allow horizontal swipe
                  children: [
                    _FeaturedTab(future: _featuredFuture),
                    _LatestTab(future: _latestFuture),
                  ],
                ),
              ),
            ],
            body: const SizedBox.shrink(), // Empty body since we're using slivers
          ),
      ),
    );
  }

  // ───────────────────────── widgets ─────────────────────────

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

  Widget _sectionTitle(BuildContext ctx, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(ctx)
                  .textTheme
                  .titleLarge!
                  .copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  )),
          const Spacer(),
          if (trailing != null) trailing,
        ],
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
      children: [
        // Section Header
        _sectionTitle(
          context,
          'Continue Reading',
          trailing: TextButton(
            onPressed: () {
              // Navigate to continue reading page
            },
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: 16),
        // Horizontal List
        SizedBox(
          height: 180, // Fixed height for better proportions
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
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
    final cs = Theme.of(context).colorScheme;
    
    // Placeholder metadata since Episode doesn't link Story details directly
    const defaultCategory = 'Love';
    const jlpt = 'N5';
    const writer = 'WRITER NAME';
    const likes = 4200;

    return Container(
      width: 140, // Match Recommend Stories card width
      height: 180, // Fixed height for better proportions
      child: InkWell(
        onTap: () {
          // Handle episode tap - navigate to reader
        },
        child: Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                height: 40, // Increased height for better proportions
                color: cs.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        writer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(jlpt, style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
              ),
              // Cover
              Expanded(
                child: Image.network(
                  'https://images.unsplash.com/photo-1519638399535-1b036603ac77?w=800',
                  fit: BoxFit.cover,
                ),
              ),
              // Footer
              Container(
                height: 56, // Increased height for better proportions
                color: cs.surfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${episode.index}  ${episode.preview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 18, color: cs.secondary),
                        const SizedBox(width: 8),
                        Text('${(likes / 1000).toStringAsFixed(1)}K', 
                             style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
  
  const _TopChartListWidget({required this.items});
  
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

// Dedicated SectionHeader widget for Top Charts
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  
  const SectionHeader({
    Key? key,
    required this.title,
    this.trailing,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12), // 24 top, 12 bottom
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
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

// Featured Stories Tab with AutomaticKeepAliveClientMixin
class _FeaturedTab extends StatefulWidget {
  final Future<List<Story>> future;
  
  const _FeaturedTab({required this.future});
  
  @override
  State<_FeaturedTab> createState() => _FeaturedTabState();
}

class _FeaturedTabState extends State<_FeaturedTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final listPadding = EdgeInsets.fromLTRB(16, 12, 16, bottomSafe + 56 + 16);
    
    return FutureBuilder<List<Story>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final stories = snapshot.data ?? <Story>[];
        final displayItems = stories.take(5).toList();
        
        return ListView.separated(
          padding: listPadding,
          itemCount: displayItems.length + 1, // +1 for See More button
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            thickness: 0.5,
          ),
           itemBuilder: (context, index) {
            if (index >= displayItems.length) {
              return _buildSeeMoreButton(context, 'Featured Stories');
            }
            
             final s = displayItems[index];
            final episodeCount = 8 + index;
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
                        // Compact book cover thumbnail
                        Container(
                          width: 72,
                          height: 108,
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
      },
    );
  }
  
  Widget _buildSeeMoreButton(BuildContext context, String tabName) {
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
                content: Text('See more $tabName stories coming soon!'),
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
}

// Latest Releases Tab with AutomaticKeepAliveClientMixin
class _LatestTab extends StatefulWidget {
  final Future<List<Story>> future;
  
  const _LatestTab({required this.future});
  
  @override
  State<_LatestTab> createState() => _LatestTabState();
}

class _LatestTabState extends State<_LatestTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final listPadding = EdgeInsets.fromLTRB(16, 12, 16, bottomSafe + 56 + 16);
    
    return FutureBuilder<List<Story>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final stories = snapshot.data ?? <Story>[];
        final displayItems = stories.skip(2).take(5).toList(); // Different subset for latest
        
        return ListView.separated(
          padding: listPadding,
          itemCount: displayItems.length + 1, // +1 for See More button
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            thickness: 0.5,
          ),
          itemBuilder: (context, index) {
            if (index >= displayItems.length) {
              return _buildSeeMoreButton(context, 'Latest Releases');
            }
            
            final s = displayItems[index];
            final episodeCount = 8 + index;
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
                        // Compact book cover thumbnail
                        Container(
                          width: 72,
                          height: 108,
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
      },
    );
  }
  
  Widget _buildSeeMoreButton(BuildContext context, String tabName) {
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
                content: Text('See more $tabName stories coming soon!'),
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
}
