import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/story.dart';
import '../../reader/reader_screen.dart';

/// MonoCollectionRow — Left static cover + right horizontal episode cards (Kahoot-style row).
class MonoCollectionRow extends StatelessWidget {
  const MonoCollectionRow({
    super.key,
    required this.episodes,
    this.title = 'Popular Mono\nCollections',
  });

  final List<Episode> episodes;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 210,
      child: ListView.builder(
        key: const PageStorageKey('mono_collection_row'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: episodes.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _IntroCard(title: title);
          final ep = episodes[i - 1];
          return _EpisodeCard(ep: ep);
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final size = const Size(160, 200); // keep existing size

    return Container(
      width: size.width,
      height: size.height,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Transparent PNG icon
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/writer.png',
                fit: BoxFit.contain,
                // Adjust if needed to avoid clipping
                width: 96,
                height: 96,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.ep});

  final Episode ep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Placeholder metadata since Episode doesn't link Story details directly.
    const defaultCategory = 'Love';
    final cover = kCategoryCover[defaultCategory] ?? kCategoryCover.values.first;
    const jlpt = 'N5';
    const writer = 'WRITER NAME';
    const likes = 4200;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(episode: ep)),
        ),
        child: Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // header
              Container(
                height: 32,
                color: cs.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 10, child: Icon(Icons.person, size: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        writer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(jlpt, style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
              ),
              // cover
              Expanded(
                child: Image.network(cover, fit: BoxFit.cover),
              ),
              // footer
              Container(
                height: 48,
                color: cs.surfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${ep.index}  ${ep.preview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 16, color: cs.secondary),
                        const SizedBox(width: 6),
                        Text(_kFormat(likes), style: Theme.of(context).textTheme.labelMedium),
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
}

String _kFormat(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// Simple mapping (move to a constants file if needed)
const kCategoryCover = {
  'Love': 'https://images.unsplash.com/photo-1519638399535-1b036603ac77?w=800',
  'Comedy': 'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=800',
  'Horror': 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800',
  'Drama': 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800',
};


