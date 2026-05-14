import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../validation/nimon_network_online_provider.dart';

typedef NimonPodRead = T Function<T>(ProviderListenable<T> provider);

/// App-level connectivity derived from `connectivity_plus` (M13D).
enum NimonConnectivityStatus { online, offline }

/// Maps `connectivity_plus` results to [NimonConnectivityStatus].
///
/// - Any [ConnectivityResult] other than [ConnectivityResult.none] ⇒ online.
/// - Only `none` (or an empty list, defensively) ⇒ offline.
NimonConnectivityStatus nimonConnectivityStatusFromResults(
  List<ConnectivityResult> results,
) {
  if (results.isEmpty) return NimonConnectivityStatus.offline;
  final anyConnected = results.any((r) => r != ConnectivityResult.none);
  return anyConnected
      ? NimonConnectivityStatus.online
      : NimonConnectivityStatus.offline;
}

/// Live connectivity stream: initial [Connectivity.checkConnectivity], then
/// [Connectivity.onConnectivityChanged].
///
/// Kept in this module so [protected_action.dart] never imports
/// `connectivity_plus`. Tests may override [nimonConnectivityStatusProvider] or
/// [nimonNetworkOnlinePod] directly.
final nimonConnectivityStatusProvider =
    StreamProvider<NimonConnectivityStatus>((ref) async* {
  final connectivity = Connectivity();
  try {
    final initial = await connectivity.checkConnectivity();
    yield nimonConnectivityStatusFromResults(initial);
  } catch (_) {
    // Unavailable (some harnesses): align with legacy default-online behavior.
    yield NimonConnectivityStatus.online;
  }
  try {
    await for (final next in connectivity.onConnectivityChanged) {
      yield nimonConnectivityStatusFromResults(next);
    }
  } catch (_) {
    // Stream ended or failed; leave [nimonNetworkOnlinePod] at last value.
  }
});

/// Updates [nimonNetworkOnlinePod] from a resolved [NimonConnectivityStatus].
///
/// Accepts [WidgetRef.read] / [ProviderContainer.read] so tests can sync without
/// a [Ref] subtype.
void syncNimonNetworkOnlinePodFromStatus(
  NimonPodRead read,
  NimonConnectivityStatus status,
) {
  read(nimonNetworkOnlinePod.notifier).state =
      status == NimonConnectivityStatus.online;
}
