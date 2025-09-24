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

    return Transform(
      alignment: Alignment.centerLeft,
      transform: matrix,
      child: Stack(
        children: [
          // global shadow - reduced to prevent overlap
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,     // was 28
                    spreadRadius: 0,    // was 2
                    offset: const Offset(6, 8), // was (12, 18)
                    color: Colors.black.withOpacity(0.18), // was 0.28
                  ),
                ],
              ),
            ),
          ),

          SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // page edge (right) - disabled when thickness is 0
                if (thickness > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    bottom: 4,
                    width: thickness,
                    child: CustomPaint(painter: _PageEdgePainter()),
                  ),

                // front cover
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: thickness,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(image: image, fit: BoxFit.cover),
                      ),
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
          ),
        ],
      ),
    );
  }
}

class _PageEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFEDEDED), Color(0xFFDFDFDF), Color(0xFFEDEDED)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, base);

   // fine page lines
    final line = Paint()
      ..color = const Color(0xFFCCCCCC).withOpacity(0.65)
      ..strokeWidth = 0.7;
    for (double y = 4; y < size.height - 4; y += 3.2) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), line);
    }

    // right bevel
    final bevel = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.35)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, bevel);
  }

  @override
  bool shouldRepaint(_PageEdgePainter oldDelegate) => false;
}
