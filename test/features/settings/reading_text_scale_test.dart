import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/settings/reading_text_scale.dart';

void main() {
  test('readingTextLinearScale maps preset sizes', () {
    expect(readingTextLinearScale('small'), closeTo(0.92, 1e-9));
    expect(readingTextLinearScale('standard'), closeTo(1.0, 1e-9));
    expect(readingTextLinearScale('large'), closeTo(1.12, 1e-9));
    expect(readingTextLinearScale('bogus'), closeTo(1.0, 1e-9));
  });
}
