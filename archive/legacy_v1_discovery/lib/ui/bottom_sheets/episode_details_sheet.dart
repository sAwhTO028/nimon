import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/episode_meta.dart';
import '../widgets/episode_action_bar.dart';

/// Shows a floating card Episode Details bottom sheet with Material 3 design.
/// 
/// Features:
/// - Floating card design with 16px margins and 24px top radius
/// - Opens at 55% height, expandable to 88% via DraggableScrollableSheet
/// - Backdrop blur (sigma 12) with dim overlay
/// - Sticky CTA buttons that never hide behind bottom navigation
/// - Proper safe area handling and keyboard avoidance
/// - Dismissible via backdrop tap and drag down
/// 
/// Parameters:
/// - [context]: The build context to show the sheet in
/// - [meta]: Episode metadata containing all display information
/// - [onStartReading]: Optional callback when user taps "Start Reading"
/// - [onSaveForLater]: Optional callback when user taps "Save for Later"
/// - [onShare]: Optional callback when user taps "Share"
/// - [onTapAuthor]: Optional callback when user taps the author name
/// - [onTapCategory]: Optional callback when user taps the category
/// 
/// Returns a Future that completes when the sheet is dismissed.
Future<void> showEpisodeDetailsSheet(
  BuildContext context, {
  required EpisodeMeta meta,
  VoidCallback? onStartReading,
  VoidCallback? onSaveForLater,
  VoidCallback? onShare,
  VoidCallback? onTapAuthor,
  VoidCallback? onTapCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black.withOpacity(0.35),
    backgroundColor: Colors.transparent,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: EpisodeDetailsSheet(
        meta: meta,
        onStartReading: onStartReading,
        onSaveForLater: onSaveForLater,
        onShare: onShare,
        onTapAuthor: onTapAuthor,
        onTapCategory: onTapCategory,
      ),
    ),
  );
}

class EpisodeDetailsSheet extends StatefulWidget {
  final EpisodeMeta meta;
  final VoidCallback? onStartReading;
  final VoidCallback? onSaveForLater;
  final VoidCallback? onShare;
  final VoidCallback? onTapAuthor;
  final VoidCallback? onTapCategory;

  const EpisodeDetailsSheet({
    super.key,
    required this.meta,
    this.onStartReading,
    this.onSaveForLater,
    this.onShare,
    this.onTapAuthor,
    this.onTapCategory,
  });

  @override
  State<EpisodeDetailsSheet> createState() => _EpisodeDetailsSheetState();
}

class _EpisodeDetailsSheetState extends State<EpisodeDetailsSheet> {
  bool _isLoading = false;

  String _formatLikes(int likes) {
    if (likes >= 1000000) {
      return '${(likes / 1000000).toStringAsFixed(1)}M';
    } else if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final bottomPadding = mediaQuery.viewPadding.bottom;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    // Responsive container width
    final containerWidth = screenWidth > 600 ? 600.0 : screenWidth - 32; // 16px margin on each side
    
    return SafeArea(
      top: false,
      bottom: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        snap: true,
        builder: (context, scrollController) {
          return Center(
            child: Container(
              width: containerWidth,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                elevation: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Handle pill
                      _buildHandle(colorScheme),
                          
                          // Scrollable content
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  
                                  // Header
                                  _buildHeader(context, colorScheme, textTheme),
                                  
                                  // Divider
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    height: 1,
                                    color: colorScheme.onSurface.withOpacity(0.06),
                                  ),
                                  
                                  // Episode Preview section
                                  if (widget.meta.preview.isNotEmpty) ...[
                                    _buildPreviewSection(context, colorScheme, textTheme),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  // Stats row
                                  _buildStatsRow(context, colorScheme, textTheme),
                                  
                                  // Bottom spacing for sticky actions
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          ),
                          
                      // Episode action bar
                      _buildActionBar(context, bottomPadding, keyboardHeight),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      width: 56,
      height: 5,
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image
        _buildCoverImage(colorScheme),
        
        const SizedBox(width: 16),
        
        // Title and metadata
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.meta.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 6),
              
              // Episode number
              Text(
                widget.meta.episodeNo,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Author row
              InkWell(
                onTap: widget.onTapAuthor,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.meta.authorName,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // JLPT chip
        _buildJLPTChip(colorScheme, textTheme),
      ],
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme) {
    return Hero(
      tag: 'episode-cover-${widget.meta.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 84,
          height: 84,
          color: colorScheme.surfaceContainerLow,
          child: widget.meta.coverUrl.isNotEmpty
              ? Image.network(
                  widget.meta.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderCover(colorScheme),
                )
              : _buildPlaceholderCover(colorScheme),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Icon(
        Icons.image,
        size: 32,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildJLPTChip(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          widget.meta.jlpt,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Text(
            'Episode Preview',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Preview card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.onSurface.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: Text(
            widget.meta.preview,
            style: textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Likes - static size
          _buildStatItem(
            icon: Icons.favorite,
            value: _formatLikes(widget.meta.likes),
            caption: 'Likes',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          
          // Read time - static size
          _buildStatItem(
            icon: Icons.access_time,
            value: widget.meta.readTime,
            caption: 'Read time',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          
          // Category (tappable) - static size
          InkWell(
            onTap: widget.onTapCategory,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildStatItem(
                icon: Icons.bookmark_outline,
                value: widget.meta.category,
                caption: 'Category',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String caption,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 26,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    double bottomPadding,
    double keyboardHeight,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPadding + keyboardHeight + 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: EpisodeActionBar(
        onSave: () async {
          if (widget.onSaveForLater != null) {
            setState(() => _isLoading = true);
            try {
              widget.onSaveForLater!();
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          }
        },
        onShare: widget.onShare,
        onStart: () {
          Navigator.of(context).pop();
          widget.onStartReading?.call();
        },
        isLoading: _isLoading,
        episodeMeta: widget.meta,
      ),
    );
  }
}