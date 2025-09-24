import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class RealBook3DCover extends StatelessWidget {
  const RealBook3DCover({
    super.key,
    required this.image,
    this.width = 180,
    this.height = 260,
    this.thickness = 0,      // spine/page thickness - set to 0 to disable page edge
    this.tiltDegrees = -18,  // Y-rotate
    this.perspective = 0.0012,
    this.borderRadius = 16,
    this.overlayTitle,
  });

  final ImageProvider image;
  final double width;
  final double height;
  final double thickness;
  final double tiltDegrees;
  final double perspective;
  final double borderRadius;
  final String? overlayTitle; // optional bottom-left title chip

  @override
  Widget build(BuildContext context) {
    final tilt = tiltDegrees * math.pi / 180;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..rotateY(tilt);

    // Adaptive shadow for theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha1 = isDark ? 0.25 : 0.10;
    final alpha2 = isDark ? 0.12 : 0.05;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          // layered, soft shadows
          boxShadow: [
            // main soft shadow
            BoxShadow(
              color: Colors.black.withOpacity(alpha1),
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
            // ambient halo
            BoxShadow(
              color: Colors.black.withOpacity(alpha2),
              blurRadius: 60,
              spreadRadius: -20,
              offset: const Offset(0, 26),
            ),
          ],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: _BookBody(
            image: image,
            width: width,
            height: height,
            thickness: thickness,
            borderRadius: borderRadius,
            overlayTitle: overlayTitle,
          ),
        ),
      ),
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody({
    required this.image,
    required this.width,
    required this.height,
    required this.thickness,
    required this.borderRadius,
    this.overlayTitle,
  });

  final ImageProvider image;
  final double width;
  final double height;
  final double thickness;
  final double borderRadius;
  final String? overlayTitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge, // prevent bleed past corners
        children: [
          // front cover
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: thickness,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high, // avoids pixel gap on curves
              ),
            ),
          ),

          // spine
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: math.max(8, thickness * 0.85),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(borderRadius * 0.9),
                  bottomLeft: Radius.circular(borderRadius * 0.9),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.10),
                    Colors.white.withOpacity(0.02),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // glossy highlight
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.transparent,
                      Colors.black.withOpacity(0.06),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // bottom title chip (black blur + white text)
          if (overlayTitle != null)
            Positioned(
              left: 12,
              right: thickness + 12,
              bottom: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.black.withOpacity(0.45),
                    child: Text(
                      overlayTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

