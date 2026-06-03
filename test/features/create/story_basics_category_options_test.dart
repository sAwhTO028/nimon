import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/story_basics_category_options.dart';

void main() {
  group('normalizeImportedStoryBasicsCategory', () {
    test('Daily Life maps to Cultural', () {
      expect(
        normalizeImportedStoryBasicsCategory('Daily Life'),
        'Cultural',
      );
    });

    test('daily_life alias maps to Cultural', () {
      expect(
        normalizeImportedStoryBasicsCategory('daily_life'),
        'Cultural',
      );
    });

    test('case-insensitive canonical Drama', () {
      expect(normalizeImportedStoryBasicsCategory('drama'), 'Drama');
    });

    test('exact canonical value unchanged', () {
      expect(normalizeImportedStoryBasicsCategory('Mystery'), 'Mystery');
    });

    test('unknown category returns empty string', () {
      expect(
        normalizeImportedStoryBasicsCategory('Not A Real Category'),
        '',
      );
    });

    test('Work maps to Business', () {
      expect(normalizeImportedStoryBasicsCategory('Work'), 'Business');
    });
  });

  group('storyBasicsCategoryDropdownValue', () {
    test('valid category unchanged', () {
      expect(storyBasicsCategoryDropdownValue('Drama'), 'Drama');
    });

    test('invalid stored value returns null', () {
      expect(storyBasicsCategoryDropdownValue('Daily Life'), isNull);
    });

    test('case-insensitive match returns canonical', () {
      expect(storyBasicsCategoryDropdownValue('drama'), 'Drama');
    });

    test('empty returns null', () {
      expect(storyBasicsCategoryDropdownValue(''), isNull);
      expect(storyBasicsCategoryDropdownValue(null), isNull);
    });
  });
}
