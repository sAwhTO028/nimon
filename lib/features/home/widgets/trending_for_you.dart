import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/story.dart';
import 'book_cover_card.dart';
import 'section_header.dart';

class TrendingForYou extends StatefulWidget {
  final List<Story> stories;

  const TrendingForYou({
    super.key,
    required this.stories,
  });

  @override
  State<TrendingForYou> createState() => _TrendingForYouState();
}

class _TrendingForYouState extends State<TrendingForYou>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  
  // Section padding constant
  static const double kSectionHPad = 16;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.90, // Default to portrait, will be updated in build()
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.addListener(_onPageChanged);
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    if (_pageController.hasClients && _pageController.position.hasContentDimensions) {
      final newIndex = (_pageController.page ?? 0).round();
      if (newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });
      }
    }
  }

  void _openStory(Story story) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed(
      '/story-details',
      arguments: {
        'title': story.title,
        'description': story.description,
        'coverUrl': story.coverUrl,
        'jlptLevel': story.jlptLevel,
        'totalEpisodes': 20,
        'storyType': story.tags.isNotEmpty ? story.tags.first : 'Story',
        'episodes': [],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final trendingStories = widget.stories.take(5).toList();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Update PageController if orientation changed
    final targetViewportFraction = isLandscape ? 0.84 : 0.90;
    if (_pageController.viewportFraction != targetViewportFraction) {
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _currentIndex,
        viewportFraction: targetViewportFraction,
      );
      // Re-add the listener after recreating the controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.addListener(_onPageChanged);
        }
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSectionHPad, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Trending For You',
            padding: EdgeInsets.zero, // No padding since container already has 16px
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padEnds: false, // IMPORTANT: keeps first card flush-left
              itemCount: trendingStories.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 12), // Tighter peek effect
                  child: _TrendingCard(
                    story: trendingStories[index],
                    onTap: () => _openStory(trendingStories[index]),
                    isLandscape: isLandscape,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final bool isLandscape;

  const _TrendingCard({
    required this.story,
    required this.onTap,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    
    // Cover dimensions based on orientation
    final coverW = (isLandscape ? 110 : 120).toDouble();
    final coverH = coverW * 1.5; // 2:3 ratio

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left: Story details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        story.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Story type – ${story.tags.isNotEmpty ? story.tags.first : 'Story'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '20 episodes',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New – Aug 2',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: Book cover - improved sizing and rounded corners
            SizedBox(
              width: coverW,
              height: coverH,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      story.coverUrl ?? 'https://picsum.photos/seed/${story.id}/600/900',
                      width: coverW,
                      height: coverH,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: coverW,
                          height: coverH,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: coverW,
                          height: coverH,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.book, size: 32, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        story.jlptLevel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

