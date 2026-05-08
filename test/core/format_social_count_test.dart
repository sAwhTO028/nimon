import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/format_social_count.dart';

void main() {
  group('formatSocialCount', () {
    test('non-negative clamp', () {
      expect(formatSocialCount(-3), '0');
    });

    test('small integers', () {
      expect(formatSocialCount(0), '0');
      expect(formatSocialCount(1), '1');
      expect(formatSocialCount(999), '999');
    });

    test('thousands with optional decimal', () {
      expect(formatSocialCount(1000), '1K');
      expect(formatSocialCount(1200), '1.2K');
      expect(formatSocialCount(9500), '9.5K');
    });

    test('rounds up near 10K boundary', () {
      expect(formatSocialCount(9999), '10K');
    });

    test('whole K from 10K', () {
      expect(formatSocialCount(10000), '10K');
      expect(formatSocialCount(12000), '12K');
      expect(formatSocialCount(999499), '999K');
    });

    test('millions', () {
      expect(formatSocialCount(1000000), '1M');
      expect(formatSocialCount(1200000), '1.2M');
      expect(formatSocialCount(12500000), '13M');
    });
  });

  group('monoReactRailPrimaryLabel', () {
    test('hides zero likes label noise', () {
      expect(monoReactRailPrimaryLabel(0), 'React');
      expect(monoReactRailPrimaryLabel(-1), 'React');
    });

    test('shows abbreviated count when positive', () {
      expect(monoReactRailPrimaryLabel(1), '1');
      expect(monoReactRailPrimaryLabel(1200), '1.2K');
    });
  });

  group('monoReactRailSemanticsLabel', () {
    test('includes like count in semantics when positive', () {
      expect(monoReactRailSemanticsLabel(0), 'React');
      expect(monoReactRailSemanticsLabel(3), 'React, 3 likes');
      expect(monoReactRailSemanticsLabel(1200), 'React, 1.2K likes');
    });
  });
}
