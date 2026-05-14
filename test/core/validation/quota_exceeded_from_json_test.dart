import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/quota_exceeded_from_json.dart';

void main() {
  group('tryParseQuotaExceededFromHttpBody', () {
    test('parses root quota_exceeded', () {
      final body = jsonEncode({
        'code': 'quota_exceeded',
        'key': 'published_mono_limit_reached',
        'limit': 30,
        'current': 31,
      });
      final q = tryParseQuotaExceededFromHttpBody(body);
      expect(q, isA<AppQuotaExceededException>());
      expect(q!.key, 'published_mono_limit_reached');
      expect(q.limit, 30);
      expect(q.current, 31);
    });

    test('parses nested error envelope', () {
      final body = jsonEncode({
        'statusCode': 403,
        'error': {
          'code': 'quota_exceeded',
          'key': 'draft_story_limit_reached',
          'limit': 50,
          'current': 50,
        },
      });
      final q = tryParseQuotaExceededFromHttpBody(body);
      expect(q?.key, 'draft_story_limit_reached');
      expect(q?.limit, 50);
    });

    test('parses nested message map defensively', () {
      final body = jsonEncode({
        'message': {
          'code': 'quota_exceeded',
          'key': 'saved_mono_limit_reached',
          'limit': 50,
          'current': 55,
        },
      });
      final q = tryParseQuotaExceededFromHttpBody(body);
      expect(q?.key, 'saved_mono_limit_reached');
    });

    test('returns null for validation_failed', () {
      final body = jsonEncode({
        'message': 'validation_failed',
        'issues': [],
      });
      expect(tryParseQuotaExceededFromHttpBody(body), isNull);
    });

    test('unknown quota key still parses exception', () {
      final body = jsonEncode({
        'code': 'quota_exceeded',
        'key': 'future_unknown_key',
        'limit': 1,
        'current': 2,
      });
      final q = tryParseQuotaExceededFromHttpBody(body);
      expect(q?.key, 'future_unknown_key');
    });
  });
}
