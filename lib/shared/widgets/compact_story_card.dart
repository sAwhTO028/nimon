import 'package:flutter/material.dart';
import 'dart:ui';

/// A shared compact story card widget that matches the Home screen's Continue Reading card
/// Used for consistent card dimensions and styling across Home and Create screens
class CompactStoryCard extends StatelessWidget {
  const CompactStoryCard({
    super.key,
    required this.title,
    required this.level,
    this.imageUrl,
    this.categoryIcon,
    this.contextText,
    this.duration,
    this.theme,
    this.onTap,
    this.width = 150,
    this.height = 200,
  });

  final String title;
  final String level;
  final String? imageUrl;
  final IconData? categoryIcon;
  final String? contextText;
  final String? duration;
  final String? theme;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return Container(
      width: width,
      height: height,
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
              // Image area with badges and title blur overlay
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
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl!,
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
                      child: _buildJLPTChip(context, level),
                    ),
                    
                    // Blur title band overlay
                    _buildTitleBandWithBlur(context, title),
                  ],
                ),
              ),
              
              // Content section
              Expanded(
                flex: 29,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Theme (if available) or Title (fallback)
                      Text(
                        theme ?? title,
                        style: themeData.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      
                      // Context or duration
                      Text(
                        contextText ?? duration ?? '',
                        style: themeData.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.secondary.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          categoryIcon ?? Icons.favorite,
          size: 32,
          color: colorScheme.primary.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildJLPTChip(BuildContext context, String jlpt) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        jlpt,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTitleBandWithBlur(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.55),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
