import 'package:flutter/material.dart';
import 'package:nimon/core/settings/content_community.dart';

/// Compact content-community chip for owner list rows (M22F-1).
///
/// Shows `MY` / `EN` / `JA` or `—` for legacy/null [contentLocale].
/// Does not display [learningLanguage] in V1.
class CommunityBadge extends StatelessWidget {
  const CommunityBadge({
    super.key,
    this.contentLocale,
    this.legacyAsMixed = false,
  });

  final String? contentLocale;

  /// When true, null/unknown [contentLocale] shows `MIX` (collection cards).
  final bool legacyAsMixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onVar = scheme.onSurfaceVariant;
    final label = legacyAsMixed
        ? contentCommunityCollectionBadgeShortLabel(contentLocale)
        : contentCommunityBadgeShortLabel(contentLocale);
    final isLegacy = legacyAsMixed
        ? normalizeContentLocaleWireCode(contentLocale) == null
        : label == '—';

    return Semantics(
      label: legacyAsMixed
          ? contentCommunityCollectionBadgeSemanticsLabel(contentLocale)
          : contentCommunityBadgeSemanticsLabel(contentLocale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isLegacy
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
              : scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onVar.withValues(alpha: isLegacy ? 0.14 : 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.4,
              color: isLegacy
                  ? onVar.withValues(alpha: 0.65)
                  : scheme.onPrimaryContainer.withValues(alpha: 0.92),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
