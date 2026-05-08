import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/guest_remote_draft_warning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeGuestRemoteDraftWarning: remote off → false', () {
    expect(
      computeGuestRemoteDraftWarning(
        useRemoteDrafts: false,
        session: const AuthSessionUnauthenticated(),
      ),
      false,
    );
  });

  test('computeGuestRemoteDraftWarning: remote on + guest → true', () {
    expect(
      computeGuestRemoteDraftWarning(
        useRemoteDrafts: true,
        session: const AuthSessionUnauthenticated(),
      ),
      true,
    );
  });

  test('computeGuestRemoteDraftWarning: remote on + authenticated → false', () {
    expect(
      computeGuestRemoteDraftWarning(
        useRemoteDrafts: true,
        session: AuthSessionAuthenticated(
          AuthUser(id: 'u', email: 'e@e.com'),
        ),
      ),
      false,
    );
  });
}
