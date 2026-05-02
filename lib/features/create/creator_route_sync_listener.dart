import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_route_sync.dart';

/// Route-change-driven creator session sync.
///
/// Stabilization rule: keep build() pure. Screens should render only, while
/// route/session synchronization happens via a single listener that runs only
/// when the router location changes (and is internally deduped).
class CreatorRouteSyncListener extends ConsumerStatefulWidget {
  const CreatorRouteSyncListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<CreatorRouteSyncListener> createState() =>
      _CreatorRouteSyncListenerState();
}

class _CreatorRouteSyncListenerState
    extends ConsumerState<CreatorRouteSyncListener> {
  GoRouter? _router;
  RouterDelegate<Object>? _delegate;

  void _detach() {
    final d = _delegate;
    if (d != null) {
      d.removeListener(_onRouterChanged);
    }
    _router = null;
    _delegate = null;
  }

  void _attach(GoRouter r) {
    if (identical(_router, r)) return;
    _detach();
    _router = r;
    final d = r.routerDelegate;
    _delegate = d;
    d.addListener(_onRouterChanged);
    // Sync once immediately for the current route.
    syncCreatorDrawerSessionForRouter(r, ref);
  }

  void _onRouterChanged() {
    final r = _router;
    if (r == null) return;
    syncCreatorDrawerSessionForRouter(r, ref);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = GoRouter.maybeOf(context);
    if (r == null) {
      _detach();
      return;
    }
    _attach(r);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

