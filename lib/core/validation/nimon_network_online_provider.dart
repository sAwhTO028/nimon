import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live connectivity signal for protected-action checks.
///
/// **M13D:** [nimonNetworkOnlinePod] is driven by the connectivity stream in
/// `lib/core/networking/connectivity_status.dart` from app startup. Defaults to **online**
/// (`true`) until the first platform check/stream event.
///
/// Tests may override [nimonNetworkOnlineProvider] directly or toggle
/// [nimonNetworkOnlinePod].
final nimonNetworkOnlinePod = StateProvider<bool>((ref) => true);

/// Effective online flag for [checkProtectedAction].
final nimonNetworkOnlineProvider = Provider<bool>(
  (ref) => ref.watch(nimonNetworkOnlinePod),
);
