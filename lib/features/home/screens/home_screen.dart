import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import '../../../data/story_repo.dart';
import '../../../models/story.dart';
import '../../../models/mono.dart';
import '../sections/horizontal_section.dart';
import '../widgets/story_card_large.dart';
import '../widgets/mono_card_small.dart';

class HomeScreen extends StatefulWidget {
  final StoryRepo repo;
  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _StoryTab { premium, newRelease }

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Story>> _future;
  String _rank = 'ALL';
  String _category = 'ALL';
  _StoryTab _tab = _StoryTab.premium;
  final _ranks = const ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'];
  final _categories = const ['ALL', 'Love', 'Comedy', 'Horror', 'Drama'];

  StoryRepo get repo => widget.repo;

  // Data helpers for premium/new release
  List<Story> _premiumStories = [];
  List<Story> _newReleaseStories = [];
  
  // Mock data for Mono collections
  late final List<Mono> _popularMonos;

  void _updateStoryLists(List<Story> stories) {
    _premiumStories = stories.take(5).toList();
    _newReleaseStories = stories.skip(2).take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _future = repo.listStories();
    _popularMonos = _createMockMonos();
  }

  List<Mono> _createMockMonos() {
    return [
      const Mono(
        id: 'mono1',
        title: 'Love Stories Collection',
        coverUrl: 'https://picsum.photos/seed/mono1/300/300',
        jlptLevel: 'N5',
        writerName: 'Yuki Tanaka',
        tags: ['Love', 'Romance'],
        likes: 1200,
      ),
      const Mono(
        id: 'mono2',
        title: 'Comedy Adventures',
        coverUrl: 'https://picsum.photos/seed/mono2/300/300',
        jlptLevel: 'N4',
        writerName: 'Hiroshi Sato',
        tags: ['Comedy', 'Adventure'],
        likes: 980,
      ),
      const Mono(
        id: 'mono3',
        title: 'Horror Tales',
        coverUrl: 'https://picsum.photos/seed/mono3/300/300',
        jlptLevel: 'N3',
        writerName: 'Akiko Yamamoto',
        tags: ['Horror', 'Mystery'],
        likes: 750,
      ),
      const Mono(
        id: 'mono4',
        title: 'Drama Series',
        coverUrl: 'https://picsum.photos/seed/mono4/300/300',
        jlptLevel: 'N2',
        writerName: 'Takeshi Nakamura',
        tags: ['Drama', 'Life'],
        likes: 1100,
      ),
    ];
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text('NIMON',
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              )),
                  const Spacer(),
                  _balancePill('\$ 98'),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Rank chips — horizontal, single line
          SliverToBoxAdapter(child: _rankRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // Category chips — horizontal, single line
          SliverToBoxAdapter(child: _categoryRow()),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Recommend Stories section
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
                // Update the story lists for premium/new release section
                _updateStoryLists(stories);
                return HorizontalSection<Story>(
                  title: 'Recommend Stories',
                  items: stories,
                  itemExtent: 260, // row height
                  itemBuilder: (_, s) => StoryCardLarge(
                    imageUrl: s.coverUrl ?? 'https://picsum.photos/seed/${s.id}/600/900',
                    title: s.title,
                    width: 160,
                    height: 220,
                  ),
                  onTap: (s) => _openDetail(s),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Popular Mono writer's collections (See more)
          SliverToBoxAdapter(
            child: HorizontalSection<Mono>(
              title: "Popular Mono writer's collections",
              items: _popularMonos,
              itemExtent: 170,
              trailing: TextButton(
                onPressed: () {}, 
                child: const Text('See more')
              ),
              itemBuilder: (_, m) => MonoCardSmall(
                imageUrl: m.coverUrl ?? 'https://picsum.photos/seed/${m.id}/300/300',
                title: m.title,
                jlpt: m.jlptLevel,
                subtitle: m.writerName,
                size: 120,
              ),
              onTap: (m) {
                // Navigate to mono detail page
                context.push('/mono/${m.id}');
              },
            ),
          ),

          // Premium/New Release section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _premiumNewReleaseSection(context),
            ),
          ),

          // bottom spacer to avoid overflow behind nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 92)),
        ],
      ),
    );
  }

  // ───────────────────────── widgets ─────────────────────────

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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(ctx)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
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

  // Premium/New Release section
  Widget _premiumNewReleaseSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Pills row
        SegmentedButton<_StoryTab>(
          segments: const [
            ButtonSegment(
              value: _StoryTab.premium,
              label: Text('Premium Stories'),
            ),
            ButtonSegment(
              value: _StoryTab.newRelease,
              label: Text('New Release'),
            ),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          style: ButtonStyle(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          onSelectionChanged: (set) => setState(() => _tab = set.first),
        ),

        const SizedBox(height: 12),

        // List for the selected tab
        _storyListForTab(context),
      ],
    );
  }

  Widget _storyListForTab(BuildContext context) {
    final items = _tab == _StoryTab.premium ? _premiumStories : _newReleaseStories;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final s = items[i];
        final episodeCount = 8 + i; // placeholder
        final desc = (s.description?.isNotEmpty == true)
            ? s.description!
            : 'Description Description Description Description Description Description Description';

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular thumbnail
                ClipOval(
                  child: Image.network(
                    s.coverUrl ?? 'https://picsum.photos/seed/${s.id}/100/100',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[300],
                        child: const Icon(Icons.book, size: 32),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),

                // Title / description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Trailing episode count
                Text(
                  '$episodeCount Episodes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
