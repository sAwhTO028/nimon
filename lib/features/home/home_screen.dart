import 'package:flutter/material.dart';
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

  void _onSelectRank(String v) {
    setState(() {
      _rank = v;
      _future = (_rank == 'ALL') ? repo.listStories() : repo.listStories(filter: _rank);
    });
  }

  void _openDetail(Story s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryDetailScreen(repo: repo, storyId: s.id), // ✅ storyId
      ),
    );
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
                      height: 240, child: Center(child: CircularProgressIndicator()));
                }
                final stories = snap.data!;
                return SizedBox(
                  height: 240,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _writerCollectionCard(context, stories[i]),
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

  Widget _writerCollectionCard(BuildContext context, Story s) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 300,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // cover
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  (s.coverUrl?.isNotEmpty ?? false)
                      ? s.coverUrl!
                      : 'https://picsum.photos/seed/col_${s.id}/640/360',
                  height: 150, width: double.infinity, fit: BoxFit.cover,
                ),
              ),
              // meta
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WRITER NAME',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.black54, letterSpacing: .2)),
                    const SizedBox(height: 6),
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
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
