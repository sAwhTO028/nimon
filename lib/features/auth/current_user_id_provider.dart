import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/dev_current_user_provider.dart';

/// Preferred owner id for creator basics / remote normalization:
/// authenticated user's id, otherwise [devCurrentUserProvider] (local / dev fallback).
final currentUserIdProvider = Provider<String>((ref) {
  final session = ref.watch(authSessionProvider);
  return switch (session) {
    AuthSessionAuthenticated(:final user) => user.id,
    _ => ref.watch(devCurrentUserProvider).userId,
  };
});
