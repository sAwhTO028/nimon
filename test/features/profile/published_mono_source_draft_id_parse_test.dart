import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

void main() {
  test('readPublishedMonoSourceDraftIdFromJson prefers top-level sourceDraftId',
      () {
    expect(
      readPublishedMonoSourceDraftIdFromJson(<String, Object?>{
        'sourceDraftId': 'draft-top',
        'content': <String, Object?>{'sourceDraftId': 'draft-nested'},
      }),
      'draft-top',
    );
  });

  test('readPublishedMonoSourceDraftIdFromJson reads content.sourceDraftId',
      () {
    expect(
      readPublishedMonoSourceDraftIdFromJson(<String, Object?>{
        'content': <String, Object?>{'sourceDraftId': 'draft-from-content'},
      }),
      'draft-from-content',
    );
  });

  test('readPublishedMonoSourceDraftIdFromJson returns null when absent', () {
    expect(
      readPublishedMonoSourceDraftIdFromJson(<String, Object?>{
        'content': <String, Object?>{},
      }),
      isNull,
    );
  });
}
