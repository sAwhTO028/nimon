import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/validation/nimon_network_online_provider.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/l10n/app_localizations.dart';

enum ProtectedActionType {
  react,
  follow,
  save,
  createStory,
  publishStory,
  createCollection,
  uploadMedia,
  editProfile,
}

enum ProtectedActionDecision {
  allowed,
  loginRequired,
  networkRequired,
  forbidden,
  disabledByPolicy,
}

/// Lightweight auth/network snapshot for UX routing (not persisted security).
class AuthStateSummary {
  const AuthStateSummary({required this.isAuthenticated});

  final bool isAuthenticated;
}

class NetworkStateSummary {
  const NetworkStateSummary({required this.isOnline});

  final bool isOnline;
}

bool _needsNetwork(ProtectedActionType _) {
  // V1: all remote social / account actions require connectivity.
  return true;
}

bool _guestRestricted(ProtectedActionType action) {
  switch (action) {
    case ProtectedActionType.react:
    case ProtectedActionType.follow:
    case ProtectedActionType.save:
    case ProtectedActionType.createStory:
    case ProtectedActionType.publishStory:
    case ProtectedActionType.createCollection:
    case ProtectedActionType.uploadMedia:
    case ProtectedActionType.editProfile:
      return true;
  }
}

ProtectedActionDecision checkProtectedAction(
  ProtectedActionType action, {
  required AuthStateSummary authState,
  required NetworkStateSummary networkState,
}) {
  if (_needsNetwork(action) && !networkState.isOnline) {
    return ProtectedActionDecision.networkRequired;
  }
  if (!authState.isAuthenticated && _guestRestricted(action)) {
    return ProtectedActionDecision.loginRequired;
  }
  return ProtectedActionDecision.allowed;
}

/// Convenience when using Riverpod network provider defaults.
ProtectedActionDecision checkProtectedActionFromRef(
  WidgetRef ref,
  ProtectedActionType action, {
  required bool isAuthenticated,
}) {
  final online = ref.read(nimonNetworkOnlineProvider);
  return checkProtectedAction(
    action,
    authState: AuthStateSummary(isAuthenticated: isAuthenticated),
    networkState: NetworkStateSummary(isOnline: online),
  );
}

/// Stable [validationFallbackMessagesEn] keys for login-required prompts (M13C).
String protectedActionLoginMessageKey(ProtectedActionType action) {
  switch (action) {
    case ProtectedActionType.react:
      return 'protected.react.login';
    case ProtectedActionType.follow:
      return 'protected.follow.login';
    case ProtectedActionType.save:
      return 'protected.save.login';
    case ProtectedActionType.createStory:
      return 'protected.createStory.login';
    case ProtectedActionType.publishStory:
      return 'protected.publishStory.login';
    case ProtectedActionType.createCollection:
      return 'protected.createCollection.login';
    case ProtectedActionType.uploadMedia:
      return 'protected.uploadMedia.login';
    case ProtectedActionType.editProfile:
      return 'protected.editProfile.login';
  }
}

Future<void> showProtectedActionPrompt(
  BuildContext context,
  ProtectedActionDecision decision,
  ProtectedActionType action,
) async {
  if (decision == ProtectedActionDecision.allowed) return;

  final body = switch (decision) {
    ProtectedActionDecision.networkRequired =>
      validationMessageKeyLocalized(context, 'network.offline'),
    ProtectedActionDecision.loginRequired => validationMessageKeyLocalized(
        context,
        protectedActionLoginMessageKey(action),
      ),
    ProtectedActionDecision.forbidden => validationMessageKeyLocalized(
        context,
        'protected.generic.forbidden',
      ),
    ProtectedActionDecision.disabledByPolicy => validationMessageKeyLocalized(
        context,
        'protected.generic.disabled',
      ),
    ProtectedActionDecision.allowed => '',
  };

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (decision == ProtectedActionDecision.loginRequired) ...[
                Text(
                  l10n.settingsSignInRequiredTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                body,
                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (decision == ProtectedActionDecision.loginRequired) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ctx.go('/login');
                  },
                  child: Text(l10n.validationCtaSignIn),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.validationCtaNotNow),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.validationCtaOk),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
