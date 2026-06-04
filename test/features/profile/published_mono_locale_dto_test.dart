import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

void main() {
  test('publishedMonoListItemDtoFromBackendJson parses locale fields', () {
    final dto = publishedMonoListItemDtoFromBackendJson({
      'id': '11111111-1111-4111-8111-000000000001',
      'ownerId': '00000000-0000-4000-8000-000000000001',
      'title': 'T',
      'category': '',
      'level': 'N5',
      'description': '',
      'displayPublishKind': 'read_only',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
      'contentLocale': 'my',
      'learningLanguage': 'ja',
    });

    expect(dto.contentLocale, 'my');
    expect(dto.learningLanguage, 'ja');
  });

  test('publishedMonoListItemDtoFromBackendJson omits legacy null locales', () {
    final dto = publishedMonoListItemDtoFromBackendJson({
      'id': '11111111-1111-4111-8111-000000000001',
      'ownerId': '00000000-0000-4000-8000-000000000001',
      'title': 'T',
      'category': '',
      'level': '',
      'description': '',
      'displayPublishKind': 'unknown',
      'createdAt': '',
      'updatedAt': '',
      'contentLocale': null,
    });

    expect(dto.contentLocale, isNull);
    expect(dto.learningLanguage, isNull);
  });
}
