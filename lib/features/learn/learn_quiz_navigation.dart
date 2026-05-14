import 'package:go_router/go_router.dart';

/// Returns the user to `/learn/[contentId]` after quiz results.
///
/// Pops stacked quiz routes (typically: result → quiz setup → hub). If the stack
/// does not contain the hub (e.g. deep link to result), falls back to [go].
Future<void> navigateQuizResultBackToLearnHub(
  GoRouter router,
  String contentId,
) async {
  bool atLearnHub() {
    final segs = router.state.uri.pathSegments;
    return segs.length == 2 && segs[0] == 'learn' && segs[1] == contentId;
  }

  if (atLearnHub()) return;

  if (!router.canPop()) {
    router.go('/learn/$contentId');
    return;
  }

  router.pop();
  await Future<void>.delayed(Duration.zero);

  if (atLearnHub()) return;

  if (router.canPop()) {
    router.pop();
    await Future<void>.delayed(Duration.zero);
  }

  if (!atLearnHub()) {
    router.go('/learn/$contentId');
  }
}
