import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/oneshot.dart';

/// Badged card widget for OneShot (Mono) content with top-left badge and top-right JLPT chip
class OneShotBadgedCard extends StatelessWidget {
  const OneShotBadgedCard({
    super.key,
    required this.oneShot,
    this.onTap,
    this.width = 160,
  });

  final OneShot oneShot;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
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
                 // Image area with overlays (reduced by 6%: 75% -> 70.5%)
                 Expanded(
                   flex: 71, // 75 - 6% = 70.5%, rounded to 71
                  child: Stack(
                    children: [
                     // Cover image - fills entire image space (sharp and clear)
                     ClipRRect(
                       borderRadius: const BorderRadius.only(
                         topLeft: Radius.circular(12),
                         topRight: Radius.circular(12),
                       ),
                       child: oneShot.coverUrl != null
                           ? Image.network(
                               oneShot.coverUrl!,
                               width: double.infinity,
                               height: double.infinity,
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) =>
                                   _buildPlaceholder(context),
                             )
                           : _buildPlaceholder(context),
                     ),
                      
                      // Top-left badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildTypeBadge(context, 'One-Short'),
                      ),
                      
                      // Top-right JLPT chip
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildJLPTChip(context, oneShot.jlpt),
                      ),
                      
                      // Blur title band overlay (reduced by 2% but remains as overlay)
                      _buildTitleBandWithBlur(context, oneShot),
                    ],
                  ),
                ),
                
                 // Footer/Base Card (reduced by 2%: 25% -> 24.5%)
                 Expanded(
                   flex: 25, // 25 - 2% = 24.5%, rounded to 25
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
                          oneShot.writerName.isNotEmpty 
                              ? oneShot.writerName[0].toUpperCase()
                              : 'W',
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
                              oneShot.writerName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Mono - ${oneShot.monoNo}',
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

  Widget _buildTitleBandWithBlur(BuildContext context, OneShot oneShot) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
            child: Text(
              'Mono ${oneShot.monoNo}',
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
    );
  }

  String _formatLikes(int likes) {
    if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }
}
