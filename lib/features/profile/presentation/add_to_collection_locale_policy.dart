import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';

/// Normalized wire codes for selected published monos (`en` | `my` | `ja`).
Set<String> distinctNormalizedMonoLocales(
  Map<String, String?> monoIdToContentLocale,
) {
  final out = <String>{};
  for (final raw in monoIdToContentLocale.values) {
    final wire = normalizeContentLocaleWireCode(raw);
    if (wire != null) out.add(wire);
  }
  return out;
}

/// True when selection spans more than one known community.
bool selectedMonosHaveMixedCommunities(
  Map<String, String?> monoIdToContentLocale,
) {
  return distinctNormalizedMonoLocales(monoIdToContentLocale).length > 1;
}

/// Whether [collection] can receive the current mono selection.
bool collectionAcceptsMonoSelection({
  required CreatorMonoCollection collection,
  required Map<String, String?> monoIdToContentLocale,
}) {
  final collWire = normalizeContentLocaleWireCode(collection.contentLocale);
  if (collWire == null) return true;

  final monoLocales = distinctNormalizedMonoLocales(monoIdToContentLocale);
  if (monoLocales.isEmpty) return true;
  if (monoLocales.length > 1) return false;
  return monoLocales.single == collWire;
}

String? collectionPickerDisabledReason({
  required CreatorMonoCollection collection,
  required Map<String, String?> monoIdToContentLocale,
}) {
  if (selectedMonosHaveMixedCommunities(monoIdToContentLocale)) {
    return 'Select monos from the same community';
  }
  if (!collectionAcceptsMonoSelection(
    collection: collection,
    monoIdToContentLocale: monoIdToContentLocale,
  )) {
    return 'Different community';
  }
  return null;
}
