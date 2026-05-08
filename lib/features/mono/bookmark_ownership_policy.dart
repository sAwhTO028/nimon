/// Bookmark/save eligibility policy.
///
/// Product rule (M8f8): users should not be able to save/bookmark their own
/// published mono content.
bool canBookmarkMono({
  required String? currentUserId,
  required String? monoOwnerId,
}) {
  final me = currentUserId?.trim();
  final owner = monoOwnerId?.trim();
  if (me == null || me.isEmpty) return true; // guest/unknown: keep existing UX
  if (owner == null || owner.isEmpty) return true; // unknown owner: keep UX
  return me != owner;
}
