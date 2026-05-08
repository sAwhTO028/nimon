import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/profile/presentation/providers/edit_profile_notifier.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  bool _hydratedControllers = false;

  late final TextEditingController _emailCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _handleCtrl;
  late final TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _displayNameCtrl = TextEditingController();
    _handleCtrl = TextEditingController();
    _bioCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(editProfileNotifierProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _displayNameCtrl.dispose();
    _handleCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _hydrateControllers(EditProfileState s) {
    _emailCtrl.text = s.email;
    _displayNameCtrl.text = s.displayName;
    _handleCtrl.text = s.handle;
    _bioCtrl.text = s.bio;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editProfileNotifierProvider);

    ref.listen(editProfileNotifierProvider, (prev, next) {
      if (!_hydratedControllers && !next.loading) {
        _hydratedControllers = true;
        _hydrateControllers(next);
      }
      if (next.errorMessage != null &&
          next.errorMessage!.trim().isNotEmpty &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!.trim()),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      if (next.lastSavedAtMs != null &&
          prev?.lastSavedAtMs != next.lastSavedAtMs) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved.'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
        Navigator.of(context).maybePop();
      }
    });

    final theme = Theme.of(context);
    final canSave =
        !s.loading && !s.saving && !s.uploadingAvatar && !s.uploadingCover;

    void syncFromControllers() {
      final n = ref.read(editProfileNotifierProvider.notifier);
      n.setDisplayName(_displayNameCtrl.text);
      n.setHandle(_handleCtrl.text);
      n.setBio(_bioCtrl.text);
    }

    Future<void> onSave() async {
      syncFromControllers();
      await ref.read(editProfileNotifierProvider.notifier).save();
    }

    Widget previewImage(String url, {required double h}) {
      final t = url.trim();
      if (t.isEmpty) {
        return Container(
          height: h,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          t,
          height: h,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: h,
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text(
              'Could not load image.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> changeAvatar() async {
      await ref
          .read(editProfileNotifierProvider.notifier)
          .pickAndUploadAvatar(source: ImageSource.gallery);
    }

    Future<void> changeCover() async {
      await ref
          .read(editProfileNotifierProvider.notifier)
          .pickAndUploadCover(source: ImageSource.gallery);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const NimonBackButton(),
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: canSave ? onSave : null,
            child: s.saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  'Cover',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    InkWell(
                      key: const ValueKey('editProfile.changeCover'),
                      onTap: s.uploadingCover ? null : changeCover,
                      borderRadius: BorderRadius.circular(14),
                      child: previewImage(s.coverImageUrl, h: 140),
                    ),
                    if (s.uploadingCover)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: s.uploadingCover ? null : changeCover,
                  child: const Text('Change cover'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Avatar',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          key: const ValueKey('editProfile.changeAvatar'),
                          onTap: s.uploadingAvatar ? null : changeAvatar,
                          customBorder: const CircleBorder(),
                          child: ClipOval(
                            child: SizedBox(
                              height: 72,
                              width: 72,
                              child: previewImage(s.avatarUrl, h: 72),
                            ),
                          ),
                        ),
                        if (s.uploadingAvatar)
                          Positioned.fill(
                            child: ClipOval(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.25),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: s.uploadingAvatar ? null : changeAvatar,
                        child: const Text('Change photo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('editProfile.displayName'),
                  controller: _displayNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('editProfile.handle'),
                  controller: _handleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Handle',
                    helperText: '3–20 chars: a–z, 0–9, _',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('editProfile.bio'),
                  controller: _bioCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('editProfile.email'),
                  controller: _emailCtrl,
                  enabled: false,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email (read-only)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
    );
  }
}
