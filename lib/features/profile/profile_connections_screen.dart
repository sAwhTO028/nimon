import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/profile/data/remote_user_follow_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_followers_pager.dart';
import 'package:nimon/features/profile/presentation/providers/profile_following_pager.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Owner-only list for Followers or Following (opened from Profile stats).
enum ProfileConnectionsKind { followers, following }

class ProfileConnectionsScreen extends ConsumerStatefulWidget {
  const ProfileConnectionsScreen({super.key, required this.kind});

  final ProfileConnectionsKind kind;

  @override
  ConsumerState<ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState
    extends ConsumerState<ProfileConnectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.kind == ProfileConnectionsKind.following) {
        final s = ref.read(authSessionProvider);
        if (s is! AuthSessionAuthenticated) {
          return;
        }
        ref.read(profileFollowingPagerProvider.notifier).loadFirstPage();
        return;
      }
      if (widget.kind == ProfileConnectionsKind.followers) {
        final s = ref.read(authSessionProvider);
        if (s is! AuthSessionAuthenticated) {
          return;
        }
        final uid = s.user.id.trim();
        if (uid.isEmpty) {
          return;
        }
        ref.read(profileFollowersPagerProvider(uid).notifier).loadFirstPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = widget.kind == ProfileConnectionsKind.followers
        ? 'Followers'
        : 'Following';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: const NimonBackButton(),
      ),
      body: widget.kind == ProfileConnectionsKind.following
          ? const _FollowingConnectionsBody()
          : const _FollowersConnectionsBody(),
    );
  }
}

class _FollowingConnectionsBody extends ConsumerWidget {
  const _FollowingConnectionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(authSessionProvider);
    if (s is! AuthSessionAuthenticated) {
      return const _ConnectionsAuthGateState(
        title: 'Sign in to see following',
        subtitle: 'Sign in to see accounts you follow.',
      );
    }
    final ps = ref.watch(profileFollowingPagerProvider);
    if (ps.isInitialLoading && ps.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ps.error != null && ps.items.isEmpty) {
      return _ConnectionsErrorState(
        title: 'Could not load following',
        message: '${ps.error}',
        onRetry: () {
          ref.read(profileFollowingPagerProvider.notifier).loadFirstPage();
        },
      );
    }
    if (!ps.isInitialLoading && ps.items.isEmpty && ps.error == null) {
      return const _ConnectionsEmptyState(
          kind: ProfileConnectionsKind.following);
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: ps.items.length + (ps.canLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        indent: 76,
        color: scheme.outlineVariant.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        if (index >= ps.items.length) {
          ref.read(profileFollowingPagerProvider.notifier).loadMore();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: ps.isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
        return _MeFollowingUserRow(user: ps.items[index]);
      },
    );
  }
}

class _FollowersConnectionsBody extends ConsumerWidget {
  const _FollowersConnectionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(authSessionProvider);
    if (s is! AuthSessionAuthenticated) {
      return const _ConnectionsAuthGateState(
        title: 'Sign in to see followers',
        subtitle: 'Sign in to see who follows you.',
      );
    }
    final uid = s.user.id.trim();
    if (uid.isEmpty) {
      return const _ConnectionsUnavailableState();
    }

    final ps = ref.watch(profileFollowersPagerProvider(uid));
    if (ps.isInitialLoading && ps.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ps.error != null && ps.items.isEmpty) {
      return _ConnectionsErrorState(
        title: 'Could not load followers',
        message: '${ps.error}',
        onRetry: () {
          ref.read(profileFollowersPagerProvider(uid).notifier).loadFirstPage();
        },
      );
    }
    if (!ps.isInitialLoading && ps.items.isEmpty && ps.error == null) {
      return const _ConnectionsEmptyState(
          kind: ProfileConnectionsKind.followers);
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: ps.items.length + (ps.canLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        indent: 76,
        color: scheme.outlineVariant.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        if (index >= ps.items.length) {
          ref.read(profileFollowersPagerProvider(uid).notifier).loadMore();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: ps.isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
        return _MeFollowingUserRow(user: ps.items[index]);
      },
    );
  }
}

class _ConnectionsUnavailableState extends StatelessWidget {
  const _ConnectionsUnavailableState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Could not determine your account. Try signing in again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsAuthGateState extends StatelessWidget {
  const _ConnectionsAuthGateState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsErrorState extends StatelessWidget {
  const _ConnectionsErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MeFollowingUserRow extends StatelessWidget {
  const _MeFollowingUserRow({required this.user});

  final MeFollowingUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = (user.displayName ?? '').trim().isEmpty
        ? 'Unknown'
        : user.displayName!.trim();
    final rawHandle = (user.handle ?? '').trim();
    final handle = rawHandle.isEmpty
        ? ''
        : (rawHandle.startsWith('@') ? rawHandle : '@$rawHandle');

    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () {
          final uid = user.userId.trim();
          if (uid.isEmpty) {
            return;
          }
          final q = Uri.encodeComponent(uid);
          context.push('/profile/public?userId=$q');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (handle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsEmptyState extends StatelessWidget {
  const _ConnectionsEmptyState({required this.kind});

  final ProfileConnectionsKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFollowers = kind == ProfileConnectionsKind.followers;
    final title =
        isFollowers ? 'No followers yet.' : 'Not following anyone yet';
    final body = isFollowers
        ? 'When someone follows you, they will show up here.'
        : 'Accounts you follow will appear here. Discover creators from the feed.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowers ? Icons.group_outlined : Icons.person_search_outlined,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
