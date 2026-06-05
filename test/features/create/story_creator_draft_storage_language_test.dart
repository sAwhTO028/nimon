import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_v1_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('local save/load round-trip preserves contentLocale and learningLanguage',
      () async {
    final draft = CreatorStoryV1.empty(
      contentLocale: 'my',
      learningLanguage: 'en',
    );
    final id = draft.id;

    await StoryCreatorDraftStorage.save(draft);
    final loaded = await StoryCreatorDraftStorage.load(draftId: id);

    expect(loaded, isNotNull);
    expect(loaded!.basics.contentLocale, 'my');
    expect(loaded.basics.learningLanguage, 'en');
  });

  test('reload does not coerce learningLanguage en to ja', () async {
    final draft = CreatorStoryV1.empty(
      contentLocale: 'ja',
      learningLanguage: 'en',
    );
    await StoryCreatorDraftStorage.save(draft);
    final loaded = await StoryCreatorDraftStorage.load(draftId: draft.id);
    expect(loaded!.basics.learningLanguage, isNot('ja'));
    expect(loaded.basics.learningLanguage, 'en');
  });

  test('legacy local draft without language keys loads with null tags', () async {
    final draft = CreatorStoryV1.empty();
    final id = draft.id;
    await StoryCreatorDraftStorage.save(draft);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nimon_creator_draft_v1_$id');
    expect(raw, isNotNull);

    final loaded = await StoryCreatorDraftStorage.load(draftId: id);
    expect(loaded!.basics.contentLocale, isNull);
    expect(loaded.basics.learningLanguage, isNull);
  });
}
