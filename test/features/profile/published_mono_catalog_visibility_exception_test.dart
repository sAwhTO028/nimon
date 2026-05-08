import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';

void main() {
  test('helpers map hidden exception to user strings', () {
    final e = PublishedMonoHiddenWhileEditingException();
    expect(
      publishedMonoCatalogDetailErrorTitle(e),
      'Story temporarily unavailable',
    );
    expect(
      publishedMonoCatalogDetailErrorBody(e),
      PublishedMonoHiddenWhileEditingException
          .kPublishedMonoHiddenWhileEditingUserMessage,
    );
  });

  test('helpers fall back for generic errors', () {
    final e = StateError('x');
    expect(
      publishedMonoCatalogDetailErrorTitle(e),
      'Could not load story details.',
    );
    expect(publishedMonoCatalogDetailErrorBody(e), contains('x'));
  });
}
