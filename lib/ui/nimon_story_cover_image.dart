import 'package:flutter/material.dart';

import 'package:nimon/ui/nimon_default_cover_asset.dart';

/// Story / mono cover: network when [coverImageUrl] is usable, else bundled default.
///
/// [coverImageUrl] is trimmed; null, empty, or whitespace-only uses
/// [nimonDefaultStoryCoverAsset]. Failed [Image.network] loads use the same asset.
class NimonStoryCoverImage extends StatelessWidget {
  const NimonStoryCoverImage({
    super.key,
    required this.coverImageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = true,
  });

  final String? coverImageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;

  static bool hasUsableCoverUrl(String? url) {
    final t = url?.trim() ?? '';
    return t.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = coverImageUrl?.trim();
    final useNetwork = hasUsableCoverUrl(trimmed);

    Widget resolved() {
      if (!useNetwork) {
        return Image.asset(
          nimonDefaultStoryCoverAsset,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
        );
      }
      return Image.network(
        trimmed!,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        gaplessPlayback: gaplessPlayback,
        errorBuilder: (_, __, ___) => Image.asset(
          nimonDefaultStoryCoverAsset,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
        ),
      );
    }

    final core = SizedBox(width: width, height: height, child: resolved());

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: core,
      );
    }
    return core;
  }
}
