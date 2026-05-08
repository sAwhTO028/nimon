/// Thrown when [GET /v1/mono/:id] or owner [GET /v1/published-monos/:id] returns **404**
/// because the story is hidden while a linked draft has unpublished edits (M5d/M5e).
class PublishedMonoHiddenWhileEditingException implements Exception {
  PublishedMonoHiddenWhileEditingException({
    this.message = kPublishedMonoHiddenWhileEditingUserMessage,
  });

  static const kPublishedMonoHiddenWhileEditingUserMessage =
      'This story is being edited and will return after republish.';

  final String message;

  @override
  String toString() => message;
}

String publishedMonoCatalogDetailErrorTitle(Object err) {
  if (err is PublishedMonoHiddenWhileEditingException) {
    return 'Story temporarily unavailable';
  }
  return 'Could not load story details.';
}

String publishedMonoCatalogDetailErrorBody(Object err) {
  if (err is PublishedMonoHiddenWhileEditingException) {
    return err.message;
  }
  return err.toString();
}
