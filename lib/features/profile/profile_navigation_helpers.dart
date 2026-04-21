import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class ProfileNavigation {
  ProfileNavigation._();

  /// Opens Profile and selects the Processing tab.
  ///
  /// Uses `go` (not `push`) to avoid stacking duplicate shell routes when called
  /// from full-screen flows like `/create`.
  ///
  /// [highlightDraftId] scrolls to that local story and briefly emphasizes its card.
  static void openProcessingTab(
    BuildContext context, {
    String? highlightDraftId,
  }) {
    final uri = GoRouterState.of(context).uri;
    final isOnProfile = uri.path.startsWith('/more');
    final onProcessing = uri.queryParameters['tab'] == 'processing';
    final next = (highlightDraftId ?? '').trim();
    final cur = (uri.queryParameters['highlight'] ?? '').trim();
    if (isOnProfile && onProcessing && cur == next) return;

    final q = <String, String>{'tab': 'processing'};
    if (next.isNotEmpty) q['highlight'] = next;
    context.go(Uri(path: '/more', queryParameters: q).toString());
  }
}

