import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class ProfileNavigation {
  ProfileNavigation._();

  /// Opens Profile and selects the Workspace tab (formerly Processing).
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
    final onProcessing = uri.queryParameters['tab'] == 'workspace';
    final next = (highlightDraftId ?? '').trim();
    final cur = (uri.queryParameters['highlight'] ?? '').trim();
    if (isOnProfile && onProcessing && cur == next) return;

    final q = <String, String>{'tab': 'workspace'};
    if (next.isNotEmpty) q['highlight'] = next;
    context.go(Uri(path: '/more', queryParameters: q).toString());
  }

  /// Opens Profile and selects the **Published** tab (same as `tab=uploaded` in the shell route).
  ///
  /// Prefer [openPublishedTabForRouter] after async work or when the caller [BuildContext]
  /// may be inactive (e.g. post-frame after [context.go]).
  static void openPublishedTab(
    BuildContext context, {
    String? highlightDraftId,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    openPublishedTabForRouter(router, highlightDraftId: highlightDraftId);
  }

  /// Same as [openPublishedTab] but uses [GoRouter] only — safe when no mounted subtree
  /// exists for the previous page (inactive [Element] / post-frame after publish).
  static void openPublishedTabForRouter(
    GoRouter router, {
    String? highlightDraftId,
  }) {
    final uri = router.state.uri;
    final isOnProfile = uri.path.startsWith('/more');
    final tab = uri.queryParameters['tab'];
    final onPublished = tab == null || tab == 'uploaded';
    final next = (highlightDraftId ?? '').trim();
    final cur = (uri.queryParameters['highlight'] ?? '').trim();
    if (isOnProfile && onPublished && cur == next) return;

    final q = <String, String>{'tab': 'uploaded'};
    if (next.isNotEmpty) q['highlight'] = next;
    router.go(Uri(path: '/more', queryParameters: q).toString());
  }
}
