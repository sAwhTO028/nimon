import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/profile/edit_profile_screen.dart';
import 'package:nimon/features/profile/data/remote_me_profile_repository.dart';
import 'package:nimon/features/profile/presentation/providers/edit_profile_notifier.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/data/media_upload_repository_provider.dart';

class _FakeMeProfileRepo implements MeProfileRepository {
  _FakeMeProfileRepo({
    required this.initial,
    this.onPatch,
    this.patchError,
  });

  final EditableProfileResponse initial;
  final void Function(Map<String, Object?> body)? onPatch;
  final Object? patchError;

  @override
  Future<EditableProfileResponse> fetchMyProfile() async {
    return initial;
  }

  @override
  Future<EditableProfileResponse> patchMyProfile({
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? coverImageUrl,
    String? bio,
  }) async {
    if (patchError != null) throw patchError!;
    onPatch?.call({
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'coverImageUrl': coverImageUrl,
      'bio': bio,
    });
    return EditableProfileResponse(
      userId: initial.userId,
      email: initial.email,
      displayName: displayName,
      handle: handle,
      avatarUrl: avatarUrl,
      coverImageUrl: coverImageUrl,
      bio: bio,
    );
  }
}

class _FakeMediaUploads extends MediaUploadRepository {
  _FakeMediaUploads({required this.url, this.error})
      : super(apiBaseUrl: 'http://stub', authHeaderBuilder: () async => {});

  final String url;
  final Object? error;

  @override
  Future<MediaUploadResponse> uploadCover(XFile file) async {
    if (error != null) throw error!;
    return MediaUploadResponse(
      url: url,
      mediaType: 'image/jpeg',
      originalName: file.name,
      sizeBytes: 123,
    );
  }
}

Widget _wrap(Widget child, {required MeProfileRepository repo}) {
  return ProviderScope(
    overrides: [
      remoteMeProfileRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => child),
                  );
                },
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Edit profile loads current values and email is read-only',
      (tester) async {
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: 'https://ex.com/a.png',
        coverImageUrl: 'https://ex.com/c.png',
        bio: 'Hello',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditProfileScreen)),
      listen: false,
    );
    await container.read(editProfileNotifierProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(find.text('Change cover'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.textContaining('URL (debug)'), findsNothing);

    // ListView is lazy; scroll to ensure the email field is built.
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump(const Duration(milliseconds: 200));

    final emailFinder = find.byKey(const ValueKey('editProfile.email'));
    if (emailFinder.evaluate().isEmpty) {
      // Defensive: if the key changes, still verify the read-only contract.
      // (The screen should always render this field.)
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '') == 'Email (read-only)',
        ),
        findsOneWidget,
      );
    } else {
      expect(emailFinder, findsOneWidget);
    }

    final email = tester.widget<TextField>(
      emailFinder.evaluate().isNotEmpty
          ? emailFinder
          : find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  (w.decoration?.labelText ?? '') == 'Email (read-only)',
            ),
    );
    expect(email.enabled, isFalse);
    expect(email.readOnly, isTrue);
    expect(find.text('a@b.com'), findsOneWidget);
  });

  testWidgets('Save sends PATCH body and pops back with success snackbar',
      (tester) async {
    Map<String, Object?>? patched;
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      onPatch: (b) => patched = b,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditProfileScreen)),
      listen: false,
    );
    await container.read(editProfileNotifierProvider.notifier).load();
    await tester.pumpAndSettle();

    // Ensure the fields are visible/interactive.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('editProfile.handle')),
      'new_handle',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editProfile.bio')),
      'New bio',
    );

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50)); // start save
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));

    expect(patched, isNotNull);
    expect(patched!['handle'], 'new_handle');
    expect(patched!['bio'], 'New bio');

    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('Save strips leading @ from handle in PATCH body',
      (tester) async {
    Map<String, Object?>? patched;
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      onPatch: (b) => patched = b,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditProfileScreen)),
      listen: false,
    );
    await container.read(editProfileNotifierProvider.notifier).load();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('editProfile.handle')),
      '@new_handle',
    );

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));

    expect(patched, isNotNull);
    expect(patched!['handle'], 'new_handle');
  });

  testWidgets('Avatar upload success updates avatarUrl in PATCH body',
      (tester) async {
    Map<String, Object?>? patched;
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      onPatch: (b) => patched = b,
    );

    Future<XFile?> fakePick({required ImageSource source}) async {
      return XFile('test-assets/avatar.jpg', name: 'avatar.jpg');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
          editProfilePickImageProvider.overrideWithValue(fakePick),
          mediaUploadRepositoryProvider.overrideWithValue(
            _FakeMediaUploads(url: 'https://cdn.test/avatar.jpg'),
          ),
        ],
        child: MaterialApp(home: const EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change photo'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));

    expect(patched, isNotNull);
    expect(patched!['avatarUrl'], 'https://cdn.test/avatar.jpg');
  });

  testWidgets('Cover upload success updates coverImageUrl in PATCH body',
      (tester) async {
    Map<String, Object?>? patched;
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      onPatch: (b) => patched = b,
    );

    Future<XFile?> fakePick({required ImageSource source}) async {
      return XFile('test-assets/cover.jpg', name: 'cover.jpg');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
          editProfilePickImageProvider.overrideWithValue(fakePick),
          mediaUploadRepositoryProvider.overrideWithValue(
            _FakeMediaUploads(url: 'https://cdn.test/cover.jpg'),
          ),
        ],
        child: MaterialApp(home: const EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change cover'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));

    expect(patched, isNotNull);
    expect(patched!['coverImageUrl'], 'https://cdn.test/cover.jpg');
  });

  testWidgets('Upload failure shows message and does not set URL',
      (tester) async {
    Map<String, Object?>? patched;
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'Alice',
        handle: 'alice_1',
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      onPatch: (b) => patched = b,
    );

    Future<XFile?> fakePick({required ImageSource source}) async {
      return XFile('test-assets/avatar.jpg', name: 'avatar.jpg');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMeProfileRepositoryProvider.overrideWithValue(repo),
          editProfilePickImageProvider.overrideWithValue(fakePick),
          mediaUploadRepositoryProvider.overrideWithValue(
            _FakeMediaUploads(
              url: '',
              error: MediaUploadException('This file is too large for upload.'),
            ),
          ),
        ],
        child: MaterialApp(home: const EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change photo'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('This file is too large for upload.'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(patched, isNotNull);
    expect((patched!['avatarUrl'] as String),
        isNot('https://cdn.test/avatar.jpg'));
  });

  testWidgets('handle_taken shows friendly message', (tester) async {
    final repo = _FakeMeProfileRepo(
      initial: const EditableProfileResponse(
        userId: 'u1',
        email: 'a@b.com',
        displayName: null,
        handle: null,
        avatarUrl: null,
        coverImageUrl: null,
        bio: null,
      ),
      patchError: StateError('That handle is taken.'),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), repo: repo));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('That handle is taken.'), findsOneWidget);
  });
}
