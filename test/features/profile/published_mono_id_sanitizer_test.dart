import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_id_sanitizer.dart';

void main() {
  test('PublishedMonoIdSanitizer.sanitize keeps only UUIDv4 and dedupes', () {
    final out = PublishedMonoIdSanitizer.sanitize([
      '  ',
      'not-a-uuid',
      '00000000-0000-4000-8000-000000000000',
      '00000000-0000-4000-8000-000000000000',
      '00000000-0000-5000-8000-000000000000', // v5 → drop
    ]);
    expect(out, ['00000000-0000-4000-8000-000000000000']);
  });
}
