import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/features/profile/discard_published_edit_staging_overlay_flow.dart';

void main() {
  testWidgets(
    'M17E-7: cancel-edit flow closes loading overlay before returning on quota',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    await discardPublishedEditStagingWithBlockingOverlay(
                      context: context,
                      discardStaging: () async {
                        events.add('discard_start');
                        throw const AppQuotaExceededException(
                          key: 'published_mono_limit_reached',
                          limit: 30,
                          current: 30,
                        );
                      },
                      openBlockingLoading: (ctx, msg) {
                        events.add('overlay_open');
                        return () => events.add('overlay_close');
                      },
                    );
                    events.add('after_flow');
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        events,
        ['overlay_open', 'discard_start', 'overlay_close', 'after_flow'],
      );
    },
  );

  testWidgets(
    'M17E-7: cancel-edit success closes overlay before caller continues',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    final r =
                        await discardPublishedEditStagingWithBlockingOverlay(
                      context: context,
                      discardStaging: () async {
                        events.add('discard');
                        return true;
                      },
                      openBlockingLoading: (ctx, msg) {
                        events.add('overlay_open');
                        return () => events.add('overlay_close');
                      },
                    );
                    events.add('after:${r.success}');
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(
        events,
        ['overlay_open', 'discard', 'overlay_close', 'after:true'],
      );
    },
  );
}
