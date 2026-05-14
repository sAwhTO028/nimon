import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/networking/connectivity_status.dart';
import 'package:nimon/core/validation/nimon_network_online_provider.dart';
import 'package:nimon/core/validation/protected_action.dart';

void main() {
  group('nimonConnectivityStatusFromResults', () {
    test('none only => offline', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.none]),
        NimonConnectivityStatus.offline,
      );
    });

    test('wifi => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.wifi]),
        NimonConnectivityStatus.online,
      );
    });

    test('mobile => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.mobile]),
        NimonConnectivityStatus.online,
      );
    });

    test('ethernet => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.ethernet]),
        NimonConnectivityStatus.online,
      );
    });

    test('vpn => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.vpn]),
        NimonConnectivityStatus.online,
      );
    });

    test('bluetooth => online', () {
      expect(
        nimonConnectivityStatusFromResults(
            const [ConnectivityResult.bluetooth]),
        NimonConnectivityStatus.online,
      );
    });

    test('other => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [ConnectivityResult.other]),
        NimonConnectivityStatus.online,
      );
    });

    test('satellite => online', () {
      expect(
        nimonConnectivityStatusFromResults(
            const [ConnectivityResult.satellite]),
        NimonConnectivityStatus.online,
      );
    });

    test('empty list => offline (defensive)', () {
      expect(
        nimonConnectivityStatusFromResults(const []),
        NimonConnectivityStatus.offline,
      );
    });

    test('mixed none + wifi => online', () {
      expect(
        nimonConnectivityStatusFromResults(const [
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        NimonConnectivityStatus.online,
      );
    });
  });

  group('nimonNetworkOnlinePod', () {
    test('can still be overridden directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(nimonNetworkOnlinePod), true);
      container.read(nimonNetworkOnlinePod.notifier).state = false;
      expect(container.read(nimonNetworkOnlinePod), false);
      expect(container.read(nimonNetworkOnlineProvider), false);
    });
  });

  group('syncNimonNetworkOnlinePodFromStatus', () {
    test('updates pod when called with container.read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      syncNimonNetworkOnlinePodFromStatus(
        container.read,
        NimonConnectivityStatus.offline,
      );
      expect(container.read(nimonNetworkOnlinePod), false);
      syncNimonNetworkOnlinePodFromStatus(
        container.read,
        NimonConnectivityStatus.online,
      );
      expect(container.read(nimonNetworkOnlinePod), true);
    });
  });

  group('stream provider override (root wiring pattern)', () {
    test('listen + sync yields offline then online on pod', () async {
      final container = ProviderContainer(
        overrides: [
          nimonConnectivityStatusProvider.overrideWith((ref) async* {
            yield NimonConnectivityStatus.offline;
            yield NimonConnectivityStatus.online;
          }),
        ],
      );
      addTearDown(container.dispose);

      final recorded = <bool>[];
      container.listen(
        nimonConnectivityStatusProvider,
        (prev, next) {
          final status = next.asData?.value;
          if (status != null) {
            syncNimonNetworkOnlinePodFromStatus(container.read, status);
            recorded.add(container.read(nimonNetworkOnlinePod));
          }
        },
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(recorded, contains(false));
      expect(recorded.last, true);
      expect(container.read(nimonNetworkOnlinePod), true);
    });
  });

  group('guest offline wins over login (M13D)', () {
    test('guest offline react => networkRequired', () {
      expect(
        checkProtectedAction(
          ProtectedActionType.react,
          authState: const AuthStateSummary(isAuthenticated: false),
          networkState: const NetworkStateSummary(isOnline: false),
        ),
        ProtectedActionDecision.networkRequired,
      );
    });
  });
}
