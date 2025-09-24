import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import '../../data/story_repo.dart';
import '../../models/story.dart';
import 'widgets/mono_row_listview.dart';

class HomeScreen extends StatefulWidget {
  final StoryRepo repo;
  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Story>> _future;
  String _rank = 'ALL';
  String _category = 'ALL';
  final _ranks = const ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'];
  final _categories = const ['ALL', 'Love', 'Comedy', 'Horror', 'Drama'];

  StoryRepo get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _future = repo.listStories();
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
            child: _sectionTitle(context, 'Recommend Stories'),
          ),
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
                return SizedBox(
                  height: 180,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _storyThumb(context, stories[i]),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Popular Mono writer's collections (See more)
          SliverToBoxAdapter(
            child: _sectionTitle(context, "Popular Mono writer's collections",
                trailing: TextButton(
                    onPressed: () {}, child: const Text('See more'))),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<Episode>>(
              future: _getPopularEpisodes(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()));
                }
                final episodes = snap.data!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MonoCollectionsRow(
                    leftImageUrl:
                        'https://picsum.photos/seed/mono-collection/400/300',
                    caption: 'Popular Mono Collections',
                    items: episodes,
                    onTap: (episode) => _openEpisode(context, episode),
                  ),
                );
              },
            ),
          ),

          // Premium/New Release buttons
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  _pillButton(context, 'Premium Stories', onTap: () {}),
                  const SizedBox(width: 12),
                  _pillButton(context, 'New Release', onTap: () {}),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('Explore>>')),
                ],
              ),
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
}
