import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/episode_meta.dart';

/// Callback types for episode bottom sheet actions
typedef OnSaveLaterCallback = Future<void> Function(String episodeId);
typedef OnStartReadingCallback = void Function(String episodeId);
typedef OnOpenCategoryCallback = void Function(String category);
typedef OnOpenAuthorCallback = void Function(String authorName);

/// Shows a premium Episode Details bottom sheet
Future<void> showEpisodeBottomSheet(
  BuildContext context,
  EpisodeMeta meta, {
  OnSaveLaterCallback? onSaveLater,
  OnStartReadingCallback? onStartReading,
  OnOpenCategoryCallback? onOpenCategory,
  OnOpenAuthorCallback? onOpenAuthor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: EpisodeBottomSheet(
        meta: meta,
        onSaveLater: onSaveLater,
        onStartReading: onStartReading,
        onOpenCategory: onOpenCategory,
        onOpenAuthor: onOpenAuthor,
      ),
    ),
  );
}

class EpisodeBottomSheet extends StatefulWidget {
  final EpisodeMeta meta;
  final OnSaveLaterCallback? onSaveLater;
  final OnStartReadingCallback? onStartReading;
  final OnOpenCategoryCallback? onOpenCategory;
  final OnOpenAuthorCallback? onOpenAuthor;

  const EpisodeBottomSheet({
    super.key,
    required this.meta,
    this.onSaveLater,
    this.onStartReading,
    this.onOpenCategory,
    this.onOpenAuthor,
  });

  @override
  State<EpisodeBottomSheet> createState() => _EpisodeBottomSheetState();
}

class _EpisodeBottomSheetState extends State<EpisodeBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _dividerOpacity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dividerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDragUpdate(double extent) {
    // Show divider when dragging past 70% height
    if (extent > 0.7) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

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
    final screenHeight = mediaQuery.size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.4, 0.6, 0.85],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            _onDragUpdate(notification.extent);
            return true;
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pull handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 72,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          _buildHeader(context, colorScheme, textTheme),
                          
                          // Animated divider
                          AnimatedBuilder(
                            animation: _dividerOpacity,
                            builder: (context, child) => Opacity(
                              opacity: _dividerOpacity.value,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 16),
                                height: 1,
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Episode Preview
                          if (widget.meta.preview.isNotEmpty) ...[
                            _buildPreviewSection(context, colorScheme, textTheme),
                            const SizedBox(height: 16),
                          ],
                          
                          // Stats row
                          _buildStatsRow(context, colorScheme, textTheme),
                          
                          const SizedBox(height: 24),
                          
                          // Actions row
                          _buildActionsRow(context, colorScheme, textTheme),
                          
                          // Bottom padding for safe area
                          SizedBox(height: mediaQuery.padding.bottom + 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episode cover
        Hero(
          tag: 'episode-cover-${widget.meta.id}',
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerLow,
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.meta.coverUrl.isNotEmpty
                ? Image.network(
                    widget.meta.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderCover(colorScheme),
                  )
                : _buildPlaceholderCover(colorScheme),
          ),
        ),
        
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
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.27,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: 'Episode title: ${widget.meta.title}',
              ),
              
              const SizedBox(height: 4),
              
              // Episode number and JLPT badge row
              Row(
                children: [
                  // Episode number (clickable)
                  InkWell(
                    onTap: () => widget.onStartReading?.call(widget.meta.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Text(
                        widget.meta.episodeNo,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // JLPT badge
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        widget.meta.jlpt,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        semanticsLabel: 'JLPT level ${widget.meta.jlpt}',
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Author row
              InkWell(
                onTap: () => widget.onOpenAuthor?.call(widget.meta.authorName),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.meta.authorName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildPreviewSection(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Episode Preview',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            widget.meta.preview,
            style: textTheme.bodyMedium?.copyWith(
              height: 1.43,
            ),
            maxLines: 4,
            overflow: TextOverflow.fade,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        // Likes
        Expanded(
          child: _buildStatItem(
            icon: Icons.favorite,
            label: _formatLikes(widget.meta.likes),
            caption: 'Likes',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
        
        // Read time
        Expanded(
          child: _buildStatItem(
            icon: Icons.schedule,
            label: widget.meta.readTime,
            caption: 'Read time',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
        
        // Category (clickable)
        Expanded(
          child: InkWell(
            onTap: () => widget.onOpenCategory?.call(widget.meta.category),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildStatItem(
                icon: CupertinoIcons.tag,
                label: widget.meta.category,
                caption: 'Category',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String caption,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionsRow(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        // Save for Later button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () async {
              if (widget.onSaveLater != null) {
                setState(() => _isLoading = true);
                try {
                  await widget.onSaveLater!(widget.meta.id);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            icon: Icon(
              Icons.bookmark_border,
              size: 20,
            ),
            label: Text('Save for Later'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Start Reading button
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onStartReading?.call(widget.meta.id);
            },
            icon: Icon(
              Icons.play_arrow,
              size: 20,
            ),
            label: Text('Start Reading'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

