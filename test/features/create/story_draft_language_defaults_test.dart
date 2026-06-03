import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/story_draft_mapper.dart';
import 'package:nimon/features/create/story_v1_model.dart';

void main() {
  test('empty draft carries contentLocale and learningLanguage on basics', () {
    final draft = CreatorStoryV1.empty(
      contentLocale: 'my',
      learningLanguage: 'ja',
    );
    expect(draft.basics.contentLocale, 'my');
    expect(draft.basics.learningLanguage, 'ja');
  });

  test('basics DTO round-trip preserves language tags', () {
    final draft = CreatorStoryV1.empty(
      contentLocale: 'en',
      learningLanguage: 'ja',
    );
    final dto = StoryDraftMapper.fromDomain(draft);
    final back = StoryDraftMapper.toDomain(dto);
    expect(back.basics.contentLocale, 'en');
    expect(back.basics.learningLanguage, 'ja');
  });
}
