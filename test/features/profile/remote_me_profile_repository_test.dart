import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_me_profile_repository.dart';

void main() {
  group('RemoteMeProfileRepository.patchMyProfile', () {
    test('validation message array: prefers mapped profile image URL message',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'PATCH');
        return http.Response(
          jsonEncode(const {
            'statusCode': 400,
            'message': ['other error', 'avatarUrl must be a URL'],
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(displayName: 'x'),
        throwsA(
          predicate<Object>(
            (e) =>
                e is StateError && e.message == 'Profile image URL is invalid.',
          ),
        ),
      );
    });

    test('validation message array: first string when no URL-field mapping',
        () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(const {
            'statusCode': 400,
            'message': ['bio is too long', 'displayName invalid'],
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(bio: 'x'),
        throwsA(
          predicate<Object>(
            (e) => e is StateError && e.message == 'bio is too long',
          ),
        ),
      );
    });

    test('validation message as string is surfaced', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(const {
            'statusCode': 400,
            'message': 'handle_invalid',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(handle: 'bad'),
        throwsA(
          predicate<Object>(
            (e) => e is StateError && e.message == 'handle_invalid',
          ),
        ),
      );
    });

    test('409 handle_taken maps to friendly copy', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(const {
            'statusCode': 409,
            'message': {'code': 'handle_taken', 'message': 'Taken'},
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(handle: 'taken'),
        throwsA(
          predicate<Object>(
            (e) => e is StateError && e.message == 'That handle is taken.',
          ),
        ),
      );
    });

    test('409 with top-level code handle_taken', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(const {
            'statusCode': 409,
            'code': 'handle_taken',
            'message': 'Conflict',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(handle: 'taken'),
        throwsA(
          predicate<Object>(
            (e) => e is StateError && e.message == 'That handle is taken.',
          ),
        ),
      );
    });

    test('unmapped HTTP error uses try-again fallback', () async {
      final client = MockClient((_) async {
        return http.Response('', 500);
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(displayName: 'x'),
        throwsA(
          predicate<Object>(
            (e) =>
                e is StateError &&
                e.message == 'Could not save profile. Please try again.',
          ),
        ),
      );
    });

    test('client exception maps to try-again copy', () async {
      final client = MockClient((_) async {
        throw Exception('network');
      });

      final repo = RemoteMeProfileRepository(
        apiBaseUrl: 'http://localhost:9999',
        client: client,
        authHeaderBuilder: () async => {'Authorization': 'Bearer t'},
      );

      expect(
        () => repo.patchMyProfile(displayName: 'x'),
        throwsA(
          predicate<Object>(
            (e) =>
                e is StateError &&
                e.message == 'Could not save profile. Please try again.',
          ),
        ),
      );
    });
  });
}
