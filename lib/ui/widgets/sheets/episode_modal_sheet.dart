import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/episode_model.dart';

/// Material 3 compliant Episode Modal Bottom Sheet
class EpisodeModalSheet extends StatelessWidget {
  final EpisodeModel episode;
  final ScrollController controller;
  final VoidCallback? onStartReading;
  final VoidCallback? onSave;

  const EpisodeModalSheet({
    super.key,
    required this.episode,
    required this.controller,
    this.onStartReading,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final bottomPadding = mediaQuery.viewPadding.bottom;
    
    // Responsive width for landscape/tablet
    final isLandscapeOrTablet = screenWidth >= 720;
    final contentWidth = isLandscapeOrTablet ? 720.0 : screenWidth;
    
    return Container(
      width: contentWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: isLandscapeOrTablet
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _buildContent(context, colorScheme, textTheme, bottomPadding),
              ),
            )
          : _buildContent(context, colorScheme, textTheme, bottomPadding),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double bottomPadding,
  ) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        // Header section
        SliverToBoxAdapter(
          child: _buildHeader(context, colorScheme, textTheme),
        ),
        
        // Divider
        SliverToBoxAdapter(
          child: Divider(
            height: 1,
            thickness: 0.5,
            indent: 20,
            endIndent: 20,
            color: colorScheme.outlineVariant,
          ),
        ),
        
        // Preview card section
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: _buildPreviewCard(context, colorScheme, textTheme),
          ),
        ),
        
        // Metrics row section
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _buildMetricsRow(context, colorScheme, textTheme),
          ),
        ),
        
        // Sticky footer with CTA buttons - positioned at bottom
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildStickyFooter(context, colorScheme, textTheme, bottomPadding),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
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
                  episode.title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Episode number
                Text(
                  'Episode ${episode.number}',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Writer row
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        episode.writerName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // JLPT chip and Share button row
          Column(
            children: [
              _buildJLPTChip(colorScheme, textTheme),
              const SizedBox(height: 8),
              // Share button
              SizedBox(
                width: 32,
                height: 32,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Episode link copied to clipboard!')),
                          ],
                        ),
                        backgroundColor: colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: colorScheme.surfaceContainerLow,
        child: episode.coverUrl.isNotEmpty
            ? Image.network(
                episode.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackCover(colorScheme),
              )
            : _buildFallbackCover(colorScheme),
      ),
    );
  }

  Widget _buildFallbackCover(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Text(
          episode.title.isNotEmpty ? episode.title[0].toUpperCase() : 'E',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildJLPTChip(ColorScheme colorScheme, TextTheme textTheme) {
    return Semantics(
      label: 'JLPT level ${episode.jlpt}',
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            episode.jlpt,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional quote icon
          Icon(
            Icons.format_quote,
            size: 20,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          
          const SizedBox(width: 8),
          
          // Preview text
          Expanded(
            child: Text(
              episode.preview,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Likes metric
          Expanded(
            child: _buildMetricCard(
              icon: Icons.favorite,
              value: episode.likesFormatted,
              caption: 'Likes',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Read time metric
          Expanded(
            child: _buildMetricCard(
              icon: Icons.access_time,
              value: episode.readTimeFormatted,
              caption: 'Read time',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Category metric
          Expanded(
            child: _buildMetricCard(
              icon: Icons.bookmark_outline,
              value: episode.category,
              caption: 'Category',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String caption,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
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
      ),
    );
  }

  Widget _buildStickyFooter(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double bottomPadding,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Save for Later button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Save for Later'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Start Reading button
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).maybePop();
                  onStartReading?.call();
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Reading'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
