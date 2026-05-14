import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/validation_issue_from_json.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';

void main() {
  test('publishedMonoMissingFriendlyMessageIfAny maps 422 unmet', () {
    final body = jsonEncode({
      'error': {
        'code': 'unprocessable_entity',
        'message': 'Full-learn publish requirements not met',
        'details': {
          'unmet': ['published_mono_missing'],
        },
      },
    });
    expect(
      publishedMonoMissingFriendlyMessageIfAny(
        statusCode: 422,
        body: body,
      ),
      kPublishFullLearnRequiresReadOnlyFirst,
    );
  });

  test('validation_failed body parses into typed issue list', () {
    final body = jsonEncode({
      'statusCode': 400,
      'message': 'validation_failed',
      'issues': [
        {
          'code': 'x',
          'field': 'story.title',
          'messageKey': 'story.title.required',
          'severity': 'blocking',
        },
      ],
    });
    final parsed = tryParseValidationIssuesFromHttpBody(body);
    expect(parsed, isNotNull);
    final ex = StoryDraftValidationFailedException(parsed!);
    expect(ex.issues.length, 1);
    expect(ex.issues.first.field, 'story.title');
  });

  test('publishedMonoMissingFriendlyMessageIfAny returns null for other 422',
      () {
    final body = jsonEncode({
      'error': {
        'code': 'unprocessable_entity',
        'message': 'Other',
        'details': {
          'unmet': ['module_vocab_not_completed']
        },
      },
    });
    expect(
      publishedMonoMissingFriendlyMessageIfAny(
        statusCode: 422,
        body: body,
      ),
      isNull,
    );
  });
}
