import 'package:flutter/widgets.dart';

/// Whether the owner Published Monos list should call [ProfilePublishedMonoPager.loadMore].
///
/// Triggers when:
/// - the list cannot scroll (`maxScrollExtent <= 0`), or
/// - the user is near the bottom, or
/// - the API reports more pages and the scroll range is still small relative to
///   the viewport (tall phone + first page(s) that barely scroll — M17C-2).
bool profilePublishedMonosShouldPrefetchNextPage(
  ScrollMetrics m, {
  required bool hasMoreFromApi,
  double nearEndPixels = 220,
  double shortScrollViewportFactor = 2.2,
}) {
  if (m.axis != Axis.vertical) return false;
  if (m.maxScrollExtent <= 0) return true;
  if (m.pixels >= m.maxScrollExtent - nearEndPixels) return true;
  final v = m.viewportDimension;
  return hasMoreFromApi &&
      m.pixels <= 8 &&
      m.maxScrollExtent > 0 &&
      v > 0 &&
      m.maxScrollExtent < v * shortScrollViewportFactor;
}
