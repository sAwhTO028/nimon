import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_startup_routing.dart';

void main() {
  group('resolveNimonAuthStartupRedirect (M17L)', () {
    test('checking + /login → /startup', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionUnknown(),
          location: '/login',
        ),
        '/startup',
      );
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionLoading(),
          location: '/login',
        ),
        '/startup',
      );
    });

    test('checking + /create path → null (allow creator deep link)', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionLoading(),
          location: '/create/story/sentences',
        ),
        isNull,
      );
    });

    test('checking + /startup → null', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionLoading(),
          location: '/startup',
        ),
        isNull,
      );
    });

    test('authenticated + /login → /mono', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: AuthSessionAuthenticated(
            AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          location: '/login',
        ),
        '/mono',
      );
    });

    test('authenticated + /startup → /mono', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: AuthSessionAuthenticated(
            AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          location: '/startup',
        ),
        '/mono',
      );
    });

    test('authenticated + /mono → null', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: AuthSessionAuthenticated(
            AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          location: '/mono',
        ),
        isNull,
      );
    });

    test('unauthenticated + /startup → /login', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionUnauthenticated(),
          location: '/startup',
        ),
        '/login',
      );
    });

    test('unauthenticated + /mono → null (guest)', () {
      expect(
        resolveNimonAuthStartupRedirect(
          auth: const AuthSessionUnauthenticated(),
          location: '/mono',
        ),
        isNull,
      );
    });
  });
}
