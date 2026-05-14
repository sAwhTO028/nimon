import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/l10n/app_localizations_en.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every known quota key resolves title and message with limit', () {
    const keys = <String>[
      'published_mono_limit_reached',
      'saved_mono_limit_reached',
      'collection_limit_reached',
      'collection_item_limit_reached',
      'draft_story_limit_reached',
    ];
    for (final k in keys) {
      final q = AppQuotaExceededException(key: k, limit: 7, current: 8);
      final s = resolveQuotaExceededStrings(l10n, q);
      expect(s.title.isNotEmpty, true, reason: k);
      expect(s.message.contains('7'), true,
          reason: '$k message should include limit');
    }
  });

  test('unknown key uses generic fallback', () {
    const q = AppQuotaExceededException(key: 'unknown', limit: 0, current: 0);
    final s = resolveQuotaExceededStrings(l10n, q);
    expect(s.title, l10n.quotaUnknownLimitTitle);
    expect(s.message, l10n.quotaUnknownLimitMessage);
    expect(s.showPremiumSecondary, false);
  });

  test('premium-related keys request secondary action', () {
    final pub = resolveQuotaExceededStrings(
      l10n,
      const AppQuotaExceededException(
        key: 'published_mono_limit_reached',
        limit: 30,
        current: 30,
      ),
    );
    expect(pub.showPremiumSecondary, true);

    final coll = resolveQuotaExceededStrings(
      l10n,
      const AppQuotaExceededException(
        key: 'collection_limit_reached',
        limit: 10,
        current: 10,
      ),
    );
    expect(coll.showPremiumSecondary, true);

    final saved = resolveQuotaExceededStrings(
      l10n,
      const AppQuotaExceededException(
        key: 'saved_mono_limit_reached',
        limit: 50,
        current: 50,
      ),
    );
    expect(saved.showPremiumSecondary, false);
  });
}
