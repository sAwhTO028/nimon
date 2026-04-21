import 'package:flutter/material.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Owner-only V1 list for Followers or Following (opened from Profile stats).
enum ProfileConnectionsKind { followers, following }

/// V1 row model (replace with API types later).
@immutable
class ProfileConnectionUser {
  const ProfileConnectionUser({
    required this.displayName,
    required this.handle,
    this.subtitle,
  });

  final String displayName;
  final String handle;
  final String? subtitle;
}

/// V1 static data — replace with API; use `[]` to exercise empty UI.
const List<ProfileConnectionUser> kV1ProfileFollowers = [
  ProfileConnectionUser(
    displayName: 'Haruka Sato',
    handle: '@haruka_reads',
    subtitle: 'JLPT N3',
  ),
  ProfileConnectionUser(
    displayName: 'Leo Park',
    handle: '@leo_mono',
    subtitle: null,
  ),
];

const List<ProfileConnectionUser> kV1ProfileFollowing = [
  ProfileConnectionUser(
    displayName: 'Nimon Picks',
    handle: '@nimonpicks',
    subtitle: 'Curated reading',
  ),
  ProfileConnectionUser(
    displayName: 'Mono Daily',
    handle: '@monodaily',
    subtitle: 'Short stories',
  ),
];

class ProfileConnectionsScreen extends StatelessWidget {
  const ProfileConnectionsScreen({super.key, required this.kind});

  final ProfileConnectionsKind kind;

  List<ProfileConnectionUser> get _users => kind == ProfileConnectionsKind.followers
      ? kV1ProfileFollowers
      : kV1ProfileFollowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        kind == ProfileConnectionsKind.followers ? 'Followers' : 'Following';
    final users = _users;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: const NimonBackButton(),
      ),
      body: users.isEmpty
          ? _ConnectionsEmptyState(kind: kind)
          : ListView.separated(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              itemBuilder: (context, index) {
                return _ConnectionUserRow(user: users[index]);
              },
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
    final title = isFollowers ? 'No followers yet' : 'Not following anyone yet';
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

class _ConnectionUserRow extends StatelessWidget {
  const _ConnectionUserRow({required this.user});

  final ProfileConnectionUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = (user.subtitle ?? '').trim();

    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Public profile for ${user.handle} — coming soon',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.25,
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
