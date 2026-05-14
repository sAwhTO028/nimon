import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/profile/workspace_draft_menu_policy.dart';

DraftListSummaryDto _summary({
  required String draftId,
  required String publishState,
  String? workspaceState,
  bool? hasUnpublishedCoreChanges,
}) {
  return DraftListSummaryDto(
    draftId: draftId,
    title: 'T',
    coverImageUrl: null,
    level: 'n5',
    category: 'drama',
    status: 'published',
    publishState: publishState,
    processingStatus: null,
    updatedAt: '2026-01-01T00:00:00.000Z',
    sentenceCount: 1,
    publishType: 'read_only',
    previewText: 'p',
    workspaceState: workspaceState,
    hasUnpublishedCoreChanges: hasUnpublishedCoreChanges,
  );
}

void main() {
  group('workspaceDraftOverflowMenuActions', () {
    test('true local draft shows Rename + Delete from this device', () {
      final s = _summary(
        draftId: 'd1',
        publishState: StoryPublishState.draft.storageKey,
        workspaceState: 'draft',
      );
      expect(workspaceDraftOverflowMenuActions(s), const [
        WorkspaceDraftOverflowMenuAction.rename,
        WorkspaceDraftOverflowMenuAction.deleteFromDevice,
      ]);
    });

    test('published edit staging shows only cancel staging action', () {
      final s = _summary(
        draftId: 'd2',
        publishState: StoryPublishState.readingOnlyPublished.storageKey,
        workspaceState: 'editing',
        hasUnpublishedCoreChanges: true,
      );
      expect(workspaceDraftOverflowMenuActions(s), const [
        WorkspaceDraftOverflowMenuAction.cancelEditingStaging,
      ]);
    });

    test('published edit staging does not include Rename', () {
      final s = _summary(
        draftId: 'd3',
        publishState: StoryPublishState.fullLearnPublished.storageKey,
        workspaceState: 'editing',
      );
      final actions = workspaceDraftOverflowMenuActions(s);
      expect(actions, isNot(contains(WorkspaceDraftOverflowMenuAction.rename)));
      expect(
        actions,
        isNot(contains(WorkspaceDraftOverflowMenuAction.deleteFromDevice)),
      );
    });
  });
}
