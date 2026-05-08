/// Response from `POST /v1/me/creator-collections/:id/items/bulk`.
class BulkAddCreatorCollectionResult {
  const BulkAddCreatorCollectionResult({
    required this.inserted,
    required this.skippedDuplicates,
    required this.skippedNotOwnedOrMissing,
  });

  final int inserted;
  final int skippedDuplicates;
  final int skippedNotOwnedOrMissing;

  factory BulkAddCreatorCollectionResult.fromJson(Map<String, Object?> m) {
    int n(Object? k) {
      final v = m[k];
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return BulkAddCreatorCollectionResult(
      inserted: n('inserted'),
      skippedDuplicates: n('skippedDuplicates'),
      skippedNotOwnedOrMissing: n('skippedNotOwnedOrMissing'),
    );
  }
}
