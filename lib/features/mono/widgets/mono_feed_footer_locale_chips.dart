import 'package:flutter/material.dart';
import 'package:nimon/core/settings/language_pair_badge_labels.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

/// Language-pair chip for Home / Following feed footer (M23A-6D-3).
///
/// Hidden when both locale dimensions are legacy-unknown (no layout jump).
class MonoFeedFooterLocaleChip extends StatelessWidget {
  const MonoFeedFooterLocaleChip({
    super.key,
    this.learningLanguage,
    this.contentLocale,
  });

  final String? learningLanguage;
  final String? contentLocale;

  @override
  Widget build(BuildContext context) {
    if (!languagePairBadgeVisibleOnDiscoverySurfaces(
      learningLanguage: learningLanguage,
      contentLocale: contentLocale,
    )) {
      return const SizedBox.shrink();
    }
    return LanguagePairBadge(
      learningLanguage: learningLanguage,
      contentLocale: contentLocale,
    );
  }
}
