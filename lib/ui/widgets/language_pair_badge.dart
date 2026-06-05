import 'package:flutter/material.dart';
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair_badge_labels.dart';

/// Compact `learning · community` chip for Search / Saved / Owner mono rows (M23A-6D-2).
///
/// Format examples: `EN · MY`, `JA · EN`. Legacy nulls render `—` segments.
class LanguagePairBadge extends StatelessWidget {
  const LanguagePairBadge({
    super.key,
    this.learningLanguage,
    this.contentLocale,
  });

  final String? learningLanguage;
  final String? contentLocale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onVar = scheme.onSurfaceVariant;
    final label = languagePairBadgeShortLabel(
      learningLanguage: learningLanguage,
      contentLocale: contentLocale,
    );
    final learnUnset = learningLanguageBadgeIsLegacyUnset(learningLanguage);
    final communityUnset =
        normalizeContentLocaleWireCode(contentLocale) == null;
    final isLegacy = label == '—' || (learnUnset && communityUnset);

    return Semantics(
      label: languagePairBadgeSemanticsLabel(
        learningLanguage: learningLanguage,
        contentLocale: contentLocale,
      ),
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
              letterSpacing: 0.2,
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
