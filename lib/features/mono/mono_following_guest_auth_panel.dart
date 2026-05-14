import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/l10n/app_localizations.dart';

/// Guest empty state for the Mono Following feed (M17K).
class MonoFollowingGuestAuthPanel extends StatelessWidget {
  const MonoFollowingGuestAuthPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.monoFollowingGuestTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.monoFollowingGuestBody,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.validationCtaSignIn),
            ),
          ],
        ),
      ),
    );
  }
}
