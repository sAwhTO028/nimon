import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/story.dart';

/// A reusable book cover card widget with realistic 3D effects
/// Used for displaying story covers in horizontal lists
class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.story,
    this.onTap,
    this.width = 120,
    this.isCircular = false,
  });

  const BookCoverCard.sm({
    super.key,
    required this.story,
    this.onTap,
    this.isCircular = false,
  }) : width = 116; // Small preset for Continue Reading

  const BookCoverCard.md({
    super.key,
    required this.story,
    this.onTap,
    this.isCircular = false,
  }) : width = 140; // Medium preset for Recommend Stories

  final Story story;
  final VoidCallback? onTap;
  final double width;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    if (isCircular) {
      return _buildCircularCard(context);
    }
    return _buildBookCard(context);
  }

  Widget _buildCircularCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(width / 2),
      child: Container(
        width: width,
        height: width, // Square for circular
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            story.coverUrl ?? 'https://picsum.photos/seed/${story.id}/600/900',
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.book, size: 32, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                // Left spine shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 0,
                  offset: const Offset(-2, 0),
                  spreadRadius: 0,
                ),
                // Right edge shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 0,
                  offset: const Offset(1, 0),
                  spreadRadius: 0,
                ),
                // Drop shadow for elevation
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  Image.network(
                    story.coverUrl ?? 'https://picsum.photos/seed/${story.id}/600/900',
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.book, size: 32, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                  // Gradient spine on left
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Title overlay - single line with tooltip and accessibility
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildStoryTitleBar(story.title),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single-line story title bar with blurred background, tooltip and accessibility
  Widget _buildStoryTitleBar(String title) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Semantics(
            label: title,
            child: Tooltip(
              message: title,
              triggerMode: TooltipTriggerMode.longPress,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
