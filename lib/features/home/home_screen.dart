import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import 'package:nimon/data/repo_singleton.dart';
import '../../data/story_repo.dart';
import '../../models/story.dart';
import '../story/story_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final StoryRepo repo;
  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Story>> _future;
  String _rank = 'ALL';
  final _genres = const ['Love', 'History', 'Comedy', 'Horror', 'Art'];

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

  void _onSelectRank(String v) {
    setState(() {
      _rank = v;
      _future = (_rank == 'ALL') ? repo.listStories() : repo.listStories(filter: _rank);
    });
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
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      )),
                  const Spacer(),
                  _coinBadge(context),
                ],
              ),
            ),
          ),

          // Rank chips — single line
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 0,
                children: ['ALL', 'D', 'C', 'B', 'A', 'S']
                    .map((r) => FilterChip(
                  label: Text(r),
                  selected: _rank == r,
                  onSelected: (_) => _onSelectRank(r),
                  showCheckmark: _rank == r,
                  selectedColor: cs.surface,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ))
                    .toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Genre chips (UI only)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _genres.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final g = _genres[i];
                  return InputChip(
                    label: Text(g),
                    onPressed: () {}, // UI-only for now
                    selected: i == 1,  // just to mimic your screenshot tick
                    showCheckmark: i == 1,
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Hero banner (horizontal scroll) ───────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) => _heroCard(context, i),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: 6,
              ),
            ),
          ),

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
                      height: 180, child: Center(child: CircularProgressIndicator()));
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
                trailing: TextButton(onPressed: () {}, child: const Text('See more'))),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<Story>>(
              future: _future,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                      height: 280, child: Center(child: CircularProgressIndicator()));
                }
                final stories = snap.data!;
                return _writerCollections(stories);
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

  Widget _sectionTitle(BuildContext ctx, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(ctx).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
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
                  color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('Banner #${i + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(12)),
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

  Widget _writerCollections(List<Story> items) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => _writerCollectionCard(items[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: items.length,
      ),
    );
  }

  Widget _writerCollectionCard(Story s) {
    return SizedBox(
      width: 320,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _openBestEpisode(context, s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      (s.coverUrl?.isNotEmpty ?? false)
                          ? s.coverUrl!
                          : 'https://picsum.photos/800/450?blur=1',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                        ),
                      ),
                    ),
                  ),
                  if (s.jlptLevel.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          s.jlptLevel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WRITER NAME',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Episode count is not available in Story; omit to keep contracts.
                        const Icon(Icons.favorite, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          '${s.likes}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
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
