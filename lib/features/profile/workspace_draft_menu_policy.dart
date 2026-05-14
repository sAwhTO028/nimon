import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';

/// Workspace overflow menu entries for a draft summary row.
enum WorkspaceDraftOverflowMenuAction {
  /// Rename draft title (true local drafts only).
  rename,

  /// Remove local draft (true local drafts only).
  deleteFromDevice,

  /// Published-edit staging: open cancel/discard flow (draft delete only).
  cancelEditingStaging,
}

/// Overflow actions for Profile > Workspace rows.
///
/// Published-edit staging rows use [cancelEditingStaging] only; true drafts
/// use [rename] + [deleteFromDevice].
List<WorkspaceDraftOverflowMenuAction> workspaceDraftOverflowMenuActions(
  DraftListSummaryDto summary,
) {
  if (effectiveDraftListWorkspaceState(summary) == 'editing') {
    return const [WorkspaceDraftOverflowMenuAction.cancelEditingStaging];
  }
  return const [
    WorkspaceDraftOverflowMenuAction.rename,
    WorkspaceDraftOverflowMenuAction.deleteFromDevice,
  ];
}
