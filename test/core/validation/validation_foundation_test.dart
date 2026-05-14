import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/auth_validators.dart';
import 'package:nimon/core/validation/collection_validators.dart';
import 'package:nimon/core/validation/learn_validators.dart';
import 'package:nimon/core/validation/nimon_network_online_provider.dart';
import 'package:nimon/core/validation/profile_validators.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/story_validators.dart';
import 'package:nimon/core/validation/validation_fallback_messages.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';

void main() {
  group('validators', () {
    test('display name length', () {
      expect(hasBlockingIssues(validateDisplayName('')), true);
      expect(hasBlockingIssues(validateDisplayName('ab')), false);
      expect(
        hasBlockingIssues(validateDisplayName(List.filled(31, 'x').join())),
        true,
      );
    });

    test('handle reserved', () {
      expect(hasBlockingIssues(validateHandle('nimon')), true);
      expect(hasBlockingIssues(validateHandle('valid_h')), false);
    });

    test('story title publish required', () {
      expect(
        hasBlockingIssues(
          validateStoryTitle('', ValidationMode.readOnlyPublish),
        ),
        true,
      );
    });

    test('story title unsafe', () {
      expect(
        hasBlockingIssues(
          validateStoryTitle('<b>x</b>', ValidationMode.draft),
        ),
        true,
      );
    });

    test('collection name symbols only', () {
      expect(hasBlockingIssues(validateCollectionName('@@@@')), true);
    });

    test('email normalize', () {
      expect(normalizeEmailInput('  A@B.COM '), 'a@b.com');
    });

    test('password bounds', () {
      expect(hasBlockingIssues(validatePassword('short')), true);
      expect(
        hasBlockingIssues(validatePassword(List.filled(65, 'a').join())),
        true,
      );
    });

    test('limits mirror backend samples', () {
      expect(storySentenceLimits['N5']!['3_5']!.minSentences, 10);
      expect(vocabularyLimits['N5']!['3_5']!.min, 8);
      expect(quizGlobalHardMax, 24);
    });

    test('quiz item', () {
      final bad = validateQuizItem(
        category: 'X',
        question: 'ok?',
        options: const ['a'],
        correctAnswer: 'a',
      );
      expect(hasBlockingIssues(bad), true);
      final good = validateQuizItem(
        category: 'Vocabulary',
        question: 'What means hello?',
        options: const ['a', 'b', 'c', 'd'],
        correctAnswer: 'a',
      );
      expect(hasBlockingIssues(good), false);
    });
  });

  group('protected action', () {
    test('guest react => loginRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.react,
        authState: const AuthStateSummary(isAuthenticated: false),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.loginRequired);
    });

    test('guest follow => loginRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.follow,
        authState: const AuthStateSummary(isAuthenticated: false),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.loginRequired);
    });

    test('guest createStory => loginRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.createStory,
        authState: const AuthStateSummary(isAuthenticated: false),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.loginRequired);
    });

    test('guest save => loginRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.save,
        authState: const AuthStateSummary(isAuthenticated: false),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.loginRequired);
    });

    test('guest publishStory => loginRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.publishStory,
        authState: const AuthStateSummary(isAuthenticated: false),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.loginRequired);
    });

    test('offline react => networkRequired', () {
      final d = checkProtectedAction(
        ProtectedActionType.react,
        authState: const AuthStateSummary(isAuthenticated: true),
        networkState: const NetworkStateSummary(isOnline: false),
      );
      expect(d, ProtectedActionDecision.networkRequired);
    });

    test('authenticated online react => allowed', () {
      final d = checkProtectedAction(
        ProtectedActionType.react,
        authState: const AuthStateSummary(isAuthenticated: true),
        networkState: const NetworkStateSummary(isOnline: true),
      );
      expect(d, ProtectedActionDecision.allowed);
    });

    test('network provider can be overridden', () {
      final container = ProviderContainer(
        overrides: [
          nimonNetworkOnlineProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(nimonNetworkOnlineProvider), false);
      final decision = checkProtectedAction(
        ProtectedActionType.react,
        authState: const AuthStateSummary(isAuthenticated: true),
        networkState: NetworkStateSummary(
          isOnline: container.read(nimonNetworkOnlineProvider),
        ),
      );
      expect(decision, ProtectedActionDecision.networkRequired);
    });
  });

  group('fallback messages', () {
    test('returns safe string for known key', () {
      final s = validationFallbackMessage('network.offline');
      expect(s.contains('internet'), true);
    });
  });
}
