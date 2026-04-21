/// Lightweight list row for processing / “my drafts” APIs (no full learn payload).
class StoryDraftProcessingItemDto {
  const StoryDraftProcessingItemDto({
    required this.draftId,
    required this.title,
    required this.updatedAt,
    required this.publishState,
    this.readinessSummary,
    this.primaryActionHint,
  });

  final String draftId;
  final String title;
  /// ISO-8601 UTC recommended.
  final String updatedAt;
  /// [StoryPublishState.storageKey].
  final String publishState;
  final String? readinessSummary;
  final String? primaryActionHint;
}
