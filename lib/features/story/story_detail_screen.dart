import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/ui/ui.dart';

// Theme tokens for light/dark mode support
class AppThemeTokens {
  // Light theme colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF6F7F9);
  static const Color onSurface = Color(0xFF282A2E);
  static const Color onSurfaceVariant = Color(0x99000000); // rgba(0,0,0,0.60)
  static const Color border = Color(0xFFE6E6E9);
  static const Color primary = Color(0xFF3556F6);
  static const Color success = Color(0xFF2FB171);
  static const Color warning = Color(0xFFF0B400);
  static const Color danger = Color(0xFFE25454);
  
  // Icon colors
  static const Color iconInactive = Color(0xFF3A3D45);
  static const Color bookmarkActive = Color(0xFFFF5A5A);
  
  // Glass button styling
  static const Color glassBackground = Color(0xB3FFFFFF); // #FFFFFFB3
  static const Color glassBorder = Color(0x40FFFFFF); // #FFFFFF40
}

class StoryDetailScreen extends StatefulWidget {
  final StoryRepo repo;
  final String storyId;
  const StoryDetailScreen({super.key, required this.repo, required this.storyId});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> with TickerProviderStateMixin {
  late Future<Story?> _storyF;
  late Future<List<Episode>> _epsF;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isFavorite = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _storyF = widget.repo.getStoryById(widget.storyId);
    _epsF = widget.repo.getEpisodesByStory(widget.storyId);
    
    // Screen enter animation: cover fade-in + small rise
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // y 8dp → 0
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Story?>(
      future: _storyF,
      builder: (context, snap) {
        final story = snap.data;
        if (story == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF9F9FB), // Updated background
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              // Scrollable content
              SafeArea(
                top: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 72), // Space for fixed header
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16), // Global horizontal padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      
                      // Book cover with animation
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _hero(story),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Title block
                      _titleBlock(story),
                      const SizedBox(height: 12),
                      
                      // Fixed 4 tags row
                      _fixedTagsRow(story),
                      const SizedBox(height: 16),
                      
                      // "What's inside" accordion
                      _whatsInsideAccordion(story),
                      const SizedBox(height: 24),
                      
                        // Episodes section
                        _episodesSection(context),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Fixed header overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildFixedHeader(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openReader(BuildContext ctx, Story? story, Episode ep) {
    ctx.push('/reader', extra: ep);
  }

  /// Fixed header overlay with proper positioning
  Widget _buildFixedHeader(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button - pinned to true top-left
              SizedBox(
                width: 44,
                height: 44,
                child: _buildGlassButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).canPop() 
                      ? Navigator.of(context).pop()
                      : context.go('/'),
                  semanticLabel: '戻る',
                ),
              ),
              
              // Right cluster - pinned to true top-right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildGlassButton(
                      icon: Icons.add,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to list')),
                      ),
                      semanticLabel: 'リストに追加',
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildGlassButton(
                      icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      onTap: _toggleFavorite,
                      semanticLabel: _isFavorite ? 'ブックマーク解除' : 'ブックマークに追加',
                      isActive: _isFavorite,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildGlassButton(
                      icon: Icons.more_vert,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('More options')),
                      ),
                      semanticLabel: 'メニュー',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Book cover - matching Recommend Stories dimensions (140x210dp)
  Widget _hero(Story s) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.10), // Subtle shadow
          ),
        ],
      ),
      child: SizedBox(
        width: 140, // Matching BookCoverCard.md width
        height: 210, // Matching BookCoverCard.md height (140 * 3/2 = 210)
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: s.coverUrl != null
                ? Image.network(
                  s.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                    color: AppThemeTokens.surfaceVariant,
                    child: Icon(
                      Icons.book_outlined,
                      size: 64,
                      color: AppThemeTokens.onSurfaceVariant,
                    ),
                  ),
                )
              : Container(
                  color: AppThemeTokens.surfaceVariant,
                  child: Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: AppThemeTokens.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    ),
  );

  /// Title block - centered without edit icon
  Widget _titleBlock(Story s) => Column(
    children: [
      // Story Title: 22sp, weight 700, center, letterSpacing +0.2
      Text(
        s.title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22, // 22sp
          fontWeight: FontWeight.w700, // Weight 700
          color: Color(0xFF282A2E), // onSurface
          letterSpacing: 0.2, // +0.2
          height: 1.3,
        ),
      ),
      
      const SizedBox(height: 6), // Top margin 6dp
      
      // Meta line: "N5 • 430 likes" → 14sp, onSurfaceVariant, center
      Text(
        '${s.jlptLevel} • ${s.likes} likes',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14, // 14sp
          color: Color(0x99000000), // onSurfaceVariant
          height: 1.4,
        ),
      ),
    ],
  );
  

  /// Fixed 4 stat cards row - N5, Love, CM Name, Premium
  Widget _fixedTagsRow(Story s) => Column(
    children: [
      // Section margin top 12dp, bottom 8dp
      const SizedBox(height: 12),
      
      // Responsive layout: single row for normal screens, wrap for narrow screens
      LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final horizontalPadding = 32.0; // 16dp * 2
          final gap = 8.0;
          
          // Calculate card width for 4 cards in a row
          final cardWidth = (screenWidth - horizontalPadding - gap * 3) / 4;
          
          // For very narrow screens (< 320dp), use Wrap with 2 rows
          if (screenWidth < 320) {
            return Wrap(
              spacing: gap,
              runSpacing: 8,
          children: [
                _buildStatCard(
                  icon: Icons.school_outlined,
                  value: "N5",
                  caption: "Level",
                  width: cardWidth,
                ),
                _buildStatCard(
                  icon: Icons.favorite_border,
                  value: "Love",
                  caption: "Category",
                  width: cardWidth,
                ),
                _buildStatCard(
                  icon: Icons.groups_2_outlined,
                  value: "CM Name",
                  caption: "Community",
                  width: cardWidth,
                ),
                _buildStatCard(
                  icon: Icons.lock_outline,
                  value: "Premium",
                  caption: "Unlock",
                  width: cardWidth,
                ),
              ],
            );
          }
          
          // Single row layout for normal screens
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.school_outlined,
                  value: "N5",
                  caption: "Level",
                  width: cardWidth,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.favorite_border,
                  value: "Love",
                  caption: "Category",
                  width: cardWidth,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.groups_2_outlined,
                  value: "CM Name",
                  caption: "Community",
                  width: cardWidth,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.lock_outline,
                  value: "Premium",
                  caption: "Unlock",
                  width: cardWidth,
                ),
              ),
            ],
          );
        },
      ),
      
      const SizedBox(height: 8), // Section margin bottom 8dp
    ],
  );
  
  /// Compact stat card for single row layout
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String caption,
    required double width,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 44,
      ),
      child: SizedBox(
        width: width,
        height: 80, // Fixed height: 80dp
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8), // Vertical padding: 8dp
      decoration: BoxDecoration(
            color: colorScheme.surface, // White background
            borderRadius: BorderRadius.circular(12), // Border radius: 12dp
            border: Border.all(
              color: colorScheme.outlineVariant, // Theme-aware border color
              width: 1,
            ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Stat: $value')),
          ),
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                label: '$value $caption',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                    // Icon at the top
                Icon(
                  icon,
                      size: 18, // Icon size: 18dp
                      color: colorScheme.onSurfaceVariant,
                ),
                    const SizedBox(height: 4), // 4dp gap
                    // Value in the middle
                Text(
                      value,
                      style: TextStyle(
                        fontSize: 12, // fontSize: 12sp
                        fontWeight: FontWeight.w500, // medium
                        height: 1.2, // lineHeight: 1.2
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                    const SizedBox(height: 2), // 2dp gap
                    // Label at the bottom
                Text(
                      caption,
                      style: TextStyle(
                        fontSize: 10, // fontSize: 10sp
                        fontWeight: FontWeight.w400, // regular
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6), // 60% opacity
                      ),
                      textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "What's inside" accordion with description
  Widget _whatsInsideAccordion(Story s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section title: "What's inside" → 16sp, weight 600, margin top 8dp
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          "What's inside",
          style: TextStyle(
            fontSize: 16, // 16sp
            fontWeight: FontWeight.w600, // Weight 600
            color: Color(0xFF282A2E), // onSurface
          ),
        ),
      ),
      
      const SizedBox(height: 8), // Divider line spacing
      
      // Description container with accordion behavior
      Container(
        decoration: BoxDecoration(
          color: AppThemeTokens.surfaceVariant, // surfaceVariant background
          border: Border.all(
            color: const Color(0xFFE9E9EC), // Card border
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12), // 12dp radius
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isDescriptionExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildCollapsedDescription(s.description),
            secondChild: _buildExpandedDescription(s.description),
          ),
        ),
      ),
    ],
  );
  
  /// Collapsed description - 3 lines with ellipsis and "See more"
  Widget _buildCollapsedDescription(String description) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Padding 12-16dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              fontSize: 14, // 14-15sp
              height: 1.6, // Line height 1.6
              color: Color(0xFF282A2E), // onSurface
              fontWeight: FontWeight.w400,
            ),
            maxLines: 3, // 3 lines with ellipsis
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = true),
            child: const Text(
              'See more',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3556F6), // primary
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Expanded description - full text with "See less"
  Widget _buildExpandedDescription(String description) {
        return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Padding 12-16dp
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
            description,
            style: const TextStyle(
              fontSize: 14, // 14-15sp
              height: 1.6, // Line height 1.6
              color: Color(0xFF282A2E), // onSurface
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = false),
            child: const Text(
              'See less',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3556F6), // primary
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  
  /// Episodes section - CardView with outlined cards
  Widget _episodesSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section title: "Episodes" → 17sp, weight 600, margin top 20-24dp, bottom 8dp
      const Padding(
        padding: EdgeInsets.only(top: 24, bottom: 8), // Margin top 20-24dp, bottom 8dp
        child: Text(
          'Episodes',
          style: TextStyle(
            fontSize: 17, // 17sp
            fontWeight: FontWeight.w600, // Weight 600
            color: Color(0xFF282A2E), // onSurface
          ),
        ),
      ),
      
      // Episodes list
      FutureBuilder<List<Episode>>(
        future: _epsF,
        builder: (context, s2) {
          final eps = s2.data ?? const <Episode>[];
          return Column(
            children: eps
                .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16), // Industry standard 16dp gap
                  child: _buildEpisodeCard(context, e),
                ))
                .toList(),
          );
        },
      ),
    ],
  );
  
  /// Generate episode title with number and descriptive title
  String _getEpisodeTitle(Episode episode) {
    // If episode has a title, use it
    if (episode.title != null && episode.title!.isNotEmpty) {
      return "Episode ${episode.index} - ${episode.title}";
    }
    
    // Mock episode titles - in real app, these would come from episode data
    final episodeTitles = [
      "Rainy Day in Kyoto",
      "Morning Conversations", 
      "The Tea House Meeting",
      "Walking Through Gardens",
      "Evening Reflections",
      "Market Adventures",
      "Train Journey",
      "Garden Party",
      "Sunset Memories",
      "New Beginnings",
    ];
    
    // Use episode index to determine title
    final episodeIndex = episode.index % episodeTitles.length;
    return "Episode ${episode.index} - ${episodeTitles[episodeIndex]}";
  }

  /// Generate episode date based on episode index
  String _getEpisodeDate(Episode episode) {
    final now = DateTime.now();
    final episodeDate = now.subtract(Duration(days: episode.index * 3)); // 3 days between episodes
    
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return "${episodeDate.day} ${months[episodeDate.month - 1]} ${episodeDate.year}";
  }

  /// Meta chips row: rating • likes (date removed - shown at top-right)
  Widget _buildMetaChipsRow(Episode episode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Semantics(
      label: 'Episode ${episode.index} - Rating 8.7 - 4.2K likes',
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: [
          // Rating chip
          _buildRatingChip(),
          // Likes chip
          _buildLikesChip(),
        ],
      ),
    );
  }

  /// Rating chip with star icon
  Widget _buildRatingChip() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return IgnorePointer(
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.brightness == Brightness.light 
              ? const Color(0xFFF3F4F6) // Light mode background
              : const Color(0xFF2A2E35), // Dark mode background
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.87),
            ),
            const SizedBox(width: 4),
            Text(
              '8.7',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant.withOpacity(0.87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Likes chip with heart icon
  Widget _buildLikesChip() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return IgnorePointer(
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.brightness == Brightness.light 
                ? const Color(0xFFE5E7EB) // Light mode border
                : const Color(0xFF374151), // Dark mode border
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite,
              size: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.87),
            ),
            const SizedBox(width: 4),
            Text(
              '4.2K',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant.withOpacity(0.87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual episode card - industry standard spacing and layout
  Widget _buildEpisodeCard(BuildContext context, Episode episode) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeTokens.surface, // Surface background
        border: Border.all(
          color: const Color(0xFFE9E9EC), // Card border
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16), // Industry standard 16dp radius
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.08), // Subtle shadow
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showEpisodeBottomSheet(context, episode),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20), // Industry standard 20dp padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: Title (left) + Date (right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Episode title - left
                    Expanded(
                      child: Text(
                        _getEpisodeTitle(episode), // Dynamic episode title
                        style: const TextStyle(
                          fontWeight: FontWeight.w600, // Semi-bold for better hierarchy
                          fontSize: 17, // Slightly larger for better readability
                          color: Color(0xFF282A2E), // Primary text color
                          height: 1.3, // Better line height
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Date - right
                    Text(
                      _getEpisodeDate(episode),
                      style: const TextStyle(
                        color: Color(0xFF6B7280), // Better contrast gray
                        fontSize: 14, // Slightly larger for readability
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16), // Industry standard 16dp spacing
                
                // Bottom: Creator (left) + Meta chips (right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Creator avatar + name
                    Row(
                      children: [
                        Container(
                          width: 28, // Slightly larger avatar
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppThemeTokens.surfaceVariant,
                            border: Border.all(
                              color: const Color(0xFFE5E7EB), // Lighter border
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 18, // Slightly larger icon
                            color: AppThemeTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12), // More spacing
                        const Text(
                          'Creator Name', // Mock creator name
                          style: TextStyle(
                            fontSize: 14, // Better readability
                            color: Color(0xFF6B7280), // Better contrast
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // Right: Meta chips row (date • rating • likes)
                    _buildMetaChipsRow(episode),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  
  /// Glass button - 44x44 circular Material button with premium styling
  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    bool isActive = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.white.withOpacity(0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0x66FFFFFF), width: 1),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.15),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              icon,
              size: 22,
              color: isActive 
                  ? AppThemeTokens.bookmarkActive // #FF5A5A (active)
                  : const Color(0xFF3A3D45), // #3A3D45 (inactive)
            ),
          ),
        ),
      ),
    );
  }

  /// Toggle favorite with smooth animation
  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Added to favorites ♥' : 'Removed from favorites'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
