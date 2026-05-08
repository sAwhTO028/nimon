import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_resume_draft.dart';

void main() {
  test(
      'publishedEditResumeDraftLookupIds tries sourceDraftId before stripped mono id',
      () {
    expect(
      CreatorDraftResumeFlow.publishedEditResumeDraftLookupIds(
        'profile-mono-uuid',
        'draft-uuid',
      ),
      ['draft-uuid', 'mono-uuid'],
    );
  });

  test(
      'publishedEditResumeDraftLookupIds dedupes sourceDraftId when same as stripped id',
      () {
    expect(
      CreatorDraftResumeFlow.publishedEditResumeDraftLookupIds(
        'profile-same',
        'same',
      ),
      ['same'],
    );
  });

  test(
      'publishedEditResumeDraftLookupIds raw draft id only when no sourceDraftId',
      () {
    expect(
      CreatorDraftResumeFlow.publishedEditResumeDraftLookupIds('draft-a', null),
      ['draft-a'],
    );
  });
}
