import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/presentation/profile_published_monos_scroll_prefetch.dart';

class _FakeScrollMetrics implements ScrollMetrics {
  _FakeScrollMetrics({
    required this.maxScrollExtent,
    required this.pixels,
    required this.axisDirection,
    this.viewportDimension = 800,
  });

  @override
  final double maxScrollExtent;

  @override
  final double pixels;

  @override
  final AxisDirection axisDirection;

  @override
  final double viewportDimension;

  @override
  Axis get axis => axisDirectionToAxis(axisDirection);

  @override
  double get minScrollExtent => 0;

  @override
  bool get hasPixels => true;

  @override
  bool get hasContentDimensions => true;

  @override
  bool get hasViewportDimension => true;

  @override
  double get devicePixelRatio => 1;

  @override
  double get extentTotal => maxScrollExtent - minScrollExtent;

  @override
  bool get outOfRange => false;

  @override
  bool get atEdge => pixels <= minScrollExtent || pixels >= maxScrollExtent;

  @override
  double get extentBefore => pixels - minScrollExtent;

  @override
  double get extentInside =>
      maxScrollExtent - minScrollExtent - extentAfter - extentBefore;

  @override
  double get extentAfter => maxScrollExtent - pixels;

  @override
  ScrollMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    double? devicePixelRatio,
  }) {
    return _FakeScrollMetrics(
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
      pixels: pixels ?? this.pixels,
      axisDirection: axisDirection ?? this.axisDirection,
      viewportDimension: viewportDimension ?? this.viewportDimension,
    );
  }
}

void main() {
  group('profilePublishedMonosShouldPrefetchNextPage', () {
    test('true when list does not scroll (maxScrollExtent == 0)', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 0,
        pixels: 0,
        axisDirection: AxisDirection.down,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: false,
        ),
        isTrue,
      );
    });

    test('true near bottom when scrollable', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 1000,
        pixels: 800,
        axisDirection: AxisDirection.down,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: false,
        ),
        isTrue,
      );
    });

    test('short scroll + hasMore at top prefetches', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 1500,
        pixels: 0,
        axisDirection: AxisDirection.down,
        viewportDimension: 800,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: true,
        ),
        isTrue,
      );
    });

    test('M17C-5: mid-range maxScrollExtent + hasMore at top prefetches (tall rows)', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 300,
        pixels: 0,
        axisDirection: AxisDirection.down,
        viewportDimension: 800,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: true,
        ),
        isTrue,
      );
    });

    test('long scroll + hasMore at top does not prefetch', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 5000,
        pixels: 0,
        axisDirection: AxisDirection.down,
        viewportDimension: 800,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: true,
        ),
        isFalse,
      );
    });

    test('false when far from bottom and no short-scroll rule', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 1000,
        pixels: 100,
        axisDirection: AxisDirection.down,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: true,
        ),
        isFalse,
      );
    });

    test('false for horizontal axis', () {
      final m = _FakeScrollMetrics(
        maxScrollExtent: 0,
        pixels: 0,
        axisDirection: AxisDirection.right,
      );
      expect(
        profilePublishedMonosShouldPrefetchNextPage(
          m,
          hasMoreFromApi: true,
        ),
        isFalse,
      );
    });
  });
}
