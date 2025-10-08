import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/story.dart';
import '../../../models/episode_meta.dart';
import '../../../ui/widgets/sheets/show_episode_modal.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Placeholder metadata since Episode doesn't link Story details directly.
    const defaultCategory = 'Love';
    final cover = kCategoryCover[defaultCategory] ?? kCategoryCover.values.first;
    const jlpt = 'N5';
    const writer = 'WRITER NAME';

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _showEpisodeBottomSheet(context, ep),
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
                    _buildTitleBandWithBlur(context, ep),
                  ],
                ),
              ),
              
              // Footer/Base Card
              Expanded(
                flex: 25,
                child: Container(
                  padding: const EdgeInsets.all(12),
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
                        radius: 14,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          writer.isNotEmpty ? writer[0].toUpperCase() : 'W',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
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
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Episode ${ep.index}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
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
            Icons.menu_book_rounded,
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

  Widget _buildTitleBandWithBlur(BuildContext context, Episode ep) {
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
                  ep.title ?? 'Episode ${ep.index}',
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

void _showEpisodeBottomSheet(BuildContext context, Episode episode) {
  // Create EpisodeMeta from Episode data
  final episodeMeta = EpisodeMeta(
    id: episode.id,
    title: episode.title ?? 'Sample Story Title',
    episodeNo: 'Episode ${episode.index}',
    authorName: 'WRITER NAME',
    coverUrl: kCategoryCover['Love'] ?? '',
    jlpt: 'N5',
    likes: 4200,
    readTime: '5 min',
    category: 'Love',
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(episode: episode),
        ),
      );
    },
  );
}



