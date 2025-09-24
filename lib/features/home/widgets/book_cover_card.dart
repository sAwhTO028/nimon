import 'package:flutter/material.dart';
import 'dart:ui';

class BookCoverCard extends StatelessWidget {
  final String? coverUrl;
  final int episodes;
  final String storyTitle;
  final VoidCallback? onTap;

  const BookCoverCard({
    super.key,
    required this.coverUrl,
    required this.episodes,
    required this.storyTitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider imgProvider = (coverUrl != null && coverUrl!.isNotEmpty)
        ? NetworkImage(coverUrl!) as ImageProvider
        : const AssetImage('assets/images/writer.png');

    // Common book radius & aspect
    const double radius = 18;
    const double blurSigma = 12;
    const double plateScale = 1.06; // a bit larger to "peek" outside
    const double badgeHorizontalPad = 8;
    const double badgeVerticalPad = 4;

    // Foreground (book) - even spacing
    final fg = Positioned(
      left: 8, // even spacing
      right: 8, // even spacing
      top: 8,
      bottom: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 3 / 4, // book proportions like the reference image
          child: Image(
            image: imgProvider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.book, size: 40, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    );

    // Background blurred plate created FROM THE SAME IMAGE - original spacing
    final bg = Transform.translate(
      offset: const Offset(8, 8), // original offset
      child: Transform.scale(
        scale: plateScale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), // original blur
              child: Image(
                image: imgProvider,
                fit: BoxFit.cover,
                // Slight dim to push it back
                color: Colors.black.withOpacity(0.08),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.book, size: 40, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Original spine on the left
    final spine = Positioned(
      left: 8, // original position
      top: 8,
      bottom: 8,
      child: Container(
        width: 12, // original width
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );

    final titleOverlay = Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55), // semi-transparent background
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(
          storyTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // BACK layer: bigger, blurred, slightly shifted down
            Positioned.fill(
              // small vertical offset to peek under the foreground
              top: 8,
              child: Transform.scale(
                scale: 1.05, // 5% bigger than the foreground
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image(
                        image: imgProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.book, size: 40, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        color: Colors.black.withOpacity(0.15), // subtle tint
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FORE layer: your current image + bottom label
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image(
                  image: imgProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, size: 40, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),

            // title overlay at bottom
            titleOverlay,
          ],
        ),
      ),
    );
  }
}
