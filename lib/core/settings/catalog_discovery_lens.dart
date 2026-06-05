import 'package:flutter/foundation.dart' show immutable;
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';

/// Viewer catalog lens for discovery APIs (`GET /v1/mono/feed`, public collections).
///
/// Backend still applies JWT prefs when query params are omitted; explicit params
/// mirror prefs for debuggability and match M23A-6A catalog helper overrides.
@immutable
class CatalogDiscoveryLens {
  const CatalogDiscoveryLens({
    required this.contentLocale,
    required this.learningLanguage,
  });

  final String contentLocale;
  final String learningLanguage;

  /// Builds wire query params for catalog discovery endpoints.
  Map<String, String> toQueryParameters() => {
        'contentLocale': contentLocale,
        'learningLanguage': learningLanguage,
      };

  /// Resolves a valid V1 pair from [prefs]; null when community unknown or same-language pair.
  static CatalogDiscoveryLens? tryFromPreferences(UserPreferences prefs) {
    final content = normalizeContentLocaleWireCode(prefs.contentLocale);
    if (content == null) return null;
    final learning = safeLearningLanguageWireCode(prefs.learningLanguage);
    if (isSameLanguagePair(
      contentLocale: content,
      learningLanguage: learning,
    )) {
      return null;
    }
    return CatalogDiscoveryLens(
      contentLocale: content,
      learningLanguage: learning,
    );
  }

  /// Merges lens into [query] when [authHeaders] includes Authorization (guest-safe).
  static void mergeIntoQueryIfAuthenticated(
    Map<String, String> query,
    CatalogDiscoveryLens? lens,
    Map<String, String> authHeaders,
  ) {
    if (lens == null) return;
    if (!authHeaders.containsKey('Authorization')) return;
    query.addAll(lens.toQueryParameters());
  }
}
