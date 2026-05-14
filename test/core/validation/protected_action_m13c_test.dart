import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/networking/network_error_mapping.dart';
import 'package:nimon/core/validation/nimon_network_online_provider.dart'
    show nimonNetworkOnlineProvider;
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/core/validation/validation_fallback_messages.dart';
import 'package:nimon/features/auth/auth_models.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_repository.dart';
import 'package:nimon/features/auth/auth_session_notifier.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_token_store.dart';
import 'package:nimon/l10n/app_localizations.dart';

class _FakeAuthTokenStore implements AuthTokenStore {
  StoredAuthTokens? _tokens;

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  _TestAuthSessionNotifier(AuthSessionState initial)
      : super(
          AuthRepository(apiBaseUrl: 'http://127.0.0.1:9'),
          _FakeAuthTokenStore(),
        ) {
    state = initial;
  }
}

void main() {
  group('M13C message keys', () {
    test('every login key resolves to non-empty fallback', () {
      for (final a in ProtectedActionType.values) {
        final k = protectedActionLoginMessageKey(a);
        final s = validationFallbackMessage(k);
        expect(s.isNotEmpty, true);
        expect(s, isNot(contains('protected.')));
      }
    });
  });

  group('checkProtectedAction guest flows', () {
    test('guest createCollection => loginRequired', () {
      expect(
        checkProtectedAction(
          ProtectedActionType.createCollection,
          authState: const AuthStateSummary(isAuthenticated: false),
          networkState: const NetworkStateSummary(isOnline: true),
        ),
        ProtectedActionDecision.loginRequired,
      );
    });

    test('guest publishStory => loginRequired', () {
      expect(
        checkProtectedAction(
          ProtectedActionType.publishStory,
          authState: const AuthStateSummary(isAuthenticated: false),
          networkState: const NetworkStateSummary(isOnline: true),
        ),
        ProtectedActionDecision.loginRequired,
      );
    });

    test('offline authenticated react => networkRequired', () {
      expect(
        checkProtectedAction(
          ProtectedActionType.react,
          authState: const AuthStateSummary(isAuthenticated: true),
          networkState: const NetworkStateSummary(isOnline: false),
        ),
        ProtectedActionDecision.networkRequired,
      );
    });

    test('authenticated online follow => allowed', () {
      expect(
        checkProtectedAction(
          ProtectedActionType.follow,
          authState: const AuthStateSummary(isAuthenticated: true),
          networkState: const NetworkStateSummary(isOnline: true),
        ),
        ProtectedActionDecision.allowed,
      );
    });
  });

  group('offline mapping', () {
    test('socket maps to offline copy', () {
      final m = offlineUserMessageIfRecognized(const SocketException('fail'));
      expect(m, validationFallbackMessage('network.offline'));
    });
  });

  group('ensureProtectedActionAllowed', () {
    testWidgets('guest follow shows Sign in sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (_) => _TestAuthSessionNotifier(
                const AuthSessionUnauthenticated(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    await ensureProtectedActionAllowed(
                      context,
                      action: ProtectedActionType.follow,
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to follow creators.'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('offline auth shows network snack (no sheet)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (_) => _TestAuthSessionNotifier(
                AuthSessionAuthenticated(
                  AuthUser(id: 'u1', email: 'a@b.com'),
                ),
              ),
            ),
            nimonNetworkOnlineProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    await ensureProtectedActionAllowed(
                      context,
                      action: ProtectedActionType.save,
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        find.text(validationFallbackMessage('network.offline')),
        findsOneWidget,
      );
    });

    testWidgets('authenticated online does not open sheet on allowed save',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (_) => _TestAuthSessionNotifier(
                AuthSessionAuthenticated(
                  AuthUser(id: 'u1', email: 'a@b.com'),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final ok = await ensureProtectedActionAllowed(
                      context,
                      action: ProtectedActionType.react,
                    );
                    expect(ok, true);
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNothing);
    });
  });
}
