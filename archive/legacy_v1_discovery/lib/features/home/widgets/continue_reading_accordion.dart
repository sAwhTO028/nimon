import 'package:flutter/material.dart';
import '../../../models/story.dart';
import 'book_cover_card.dart';

/// A professional accordion widget for "Continue Reading" section
/// Displays 3 episode cards when expanded
class ContinueReadingAccordion extends StatefulWidget {
  const ContinueReadingAccordion({
    super.key,
    this.episodes = const [],
  });

  final List<Episode> episodes;

  @override
  State<ContinueReadingAccordion> createState() => _ContinueReadingAccordionState();
}

class _ContinueReadingAccordionState extends State<ContinueReadingAccordion>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hide accordion if no episodes
    if (widget.episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      'Continue Reading',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Chevron icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion Content
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Show skeleton while loading (if needed)
    if (widget.episodes.isEmpty) {
      return _buildSkeleton();
    }

    // Show actual content - episode cards like Popular Mono writer's collections
    return SizedBox(
      height: 116 * 3 / 2, // Calculate height from BookCoverCard.sm width and aspect ratio
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.episodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final episode = widget.episodes[index];
          return _buildEpisodeCard(context, episode);
        },
      ),
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
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // Handle episode tap - navigate to reader
        },
        child: Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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
              // Cover
              Expanded(
                child: Image.network(
                  'https://images.unsplash.com/photo-1519638399535-1b036603ac77?w=800',
                  fit: BoxFit.cover,
                ),
              ),
              // Footer
              Container(
                height: 48,
                color: cs.surfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        Icon(Icons.favorite_rounded, size: 16, color: cs.secondary),
                        const SizedBox(width: 6),
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

  Widget _buildSkeleton() {
    return SizedBox(
      height: 116 * 3 / 2, // Calculate height from BookCoverCard.sm width and aspect ratio
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Container(
            width: 116,
            height: 116 * 3 / 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
            ),
          );
        },
      ),
    );
  }
}
