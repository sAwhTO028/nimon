import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/create/creator_back_policy.dart';

/// V1 Profile menu content for the in-page **push** drawer (right menu, main layer slides left).
class ProfileNavigationDrawer extends ConsumerStatefulWidget {
  /// [ProfileScreen] context for navigation and snackbars.
  final BuildContext hostContext;
  final String displayName;
  final String handle;

  /// Reverses the host push-drawer animation; await before navigating.
  final Future<void> Function() closeDrawer;

  /// When true, drawer list scroll is locked so horizontal pan closes the push drawer.
  final ValueListenable<bool> lockScrollForHorizontalPan;

  /// Push-drawer open progress; while open, vertical scroll is disabled so horizontal drag can close.
  final Animation<double> drawerMotion;

  const ProfileNavigationDrawer({
    super.key,
    required this.hostContext,
    required this.displayName,
    required this.handle,
    required this.closeDrawer,
    required this.lockScrollForHorizontalPan,
    required this.drawerMotion,
  });

  @override
  ConsumerState<ProfileNavigationDrawer> createState() =>
      _ProfileNavigationDrawerState();
}

class _ProfileNavigationDrawerState
    extends ConsumerState<ProfileNavigationDrawer> {
  bool _switchProfilesExpanded = false;

  Future<void> _closeThenRun(VoidCallback runOnHost) async {
    await widget.closeDrawer();
    if (!widget.hostContext.mounted) return;
    runOnHost();
  }

  void _toggleSwitchProfileSection() {
    setState(() => _switchProfilesExpanded = !_switchProfilesExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final session = ref.watch(authSessionProvider);

    final String headerTitle;
    final String headerSubtitle;
    switch (session) {
      case AuthSessionAuthenticated(:final user):
        final dn = user.displayName?.trim();
        final em = user.email?.trim();
        headerTitle =
            (dn != null && dn.isNotEmpty) ? dn : (em ?? widget.displayName);
        final h = user.handle?.trim();
        if (h != null && h.isNotEmpty) {
          headerSubtitle = h.startsWith('@') ? h : '@$h';
        } else {
          headerSubtitle = em ?? widget.handle;
        }
      default:
        headerTitle = 'Guest';
        headerSubtitle = 'Not signed in';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.lockScrollForHorizontalPan,
              widget.drawerMotion,
            ]),
            builder: (context, _) {
              final lockScroll = widget.lockScrollForHorizontalPan.value ||
                  widget.drawerMotion.value > 0.001;
              return SingleChildScrollView(
                physics: lockScroll
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 32,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          headerTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          headerSubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primaryContainer
                                                .withValues(alpha: 0.65),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Active profile',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onPrimaryContainer,
                                              letterSpacing: 0.15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: _toggleSwitchProfileSection,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 22,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Switch profile',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: _switchProfilesExpanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      leading: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            scheme.surfaceContainerHigh,
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 22,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      title: Text(
                                        widget.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        widget.handle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.check_circle_rounded,
                                        color: scheme.primary,
                                        size: 24,
                                      ),
                                      selected: true,
                                      selectedTileColor: scheme.primaryContainer
                                          .withValues(alpha: 0.38),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onTap: () {
                                        setState(() =>
                                            _switchProfilesExpanded = false);
                                      },
                                    ),
                                    Divider(
                                      height: 1,
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.45),
                                    ),
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      leading: Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: scheme.primary,
                                        size: 26,
                                      ),
                                      title: const Text('Add another profile'),
                                      subtitle: Text(
                                        'Coming later',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      dense: true,
                                      onTap: () {
                                        ScaffoldMessenger.of(widget.hostContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Add profile — not wired in V1'),
                                            behavior: SnackBarBehavior.floating,
                                            margin: EdgeInsets.all(16),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                      child: Text(
                        'Actions',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Material(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _DrawerNavTile(
                              icon: Icons.auto_stories_outlined,
                              label: 'Story Creator',
                              onTap: () {
                                _closeThenRun(() {
                                  ProviderScope.containerOf(
                                    widget.hostContext,
                                    listen: false,
                                  )
                                      .read(
                                          creatorEntryChannelProvider.notifier)
                                      .state = CreatorEntryChannel.shellMore;
                                  widget.hostContext.push('/create');
                                });
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            _DrawerNavTile(
                              icon: Icons.edit_outlined,
                              label: 'Edit profile',
                              onTap: () {
                                _closeThenRun(() {
                                  widget.hostContext.push('/profile/edit');
                                });
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            _DrawerNavTile(
                              icon: Icons.delete_outline_rounded,
                              label: 'Trash',
                              onTap: () {
                                _closeThenRun(() {
                                  widget.hostContext.push('/profile/trash');
                                });
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                            _DrawerNavTile(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () {
                                _closeThenRun(() {
                                  widget.hostContext.push('/settings');
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Material(
          color: scheme.surfaceContainerLow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 8 + bottomInset),
                child: _DrawerSignOutTile(
                  onTap: () async {
                    final router = GoRouter.of(widget.hostContext);
                    final go = await showDialog<bool>(
                      context: widget.hostContext,
                      useRootNavigator: true,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text(
                          'You will be signed out on this device and returned to the login screen.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );
                    if (go == true) {
                      await widget.closeDrawer();
                      if (!widget.hostContext.mounted) return;
                      await ref.read(authSessionProvider.notifier).logout();
                      if (!widget.hostContext.mounted) return;
                      router.go('/login');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      minLeadingWidth: 40,
      horizontalTitleGap: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        icon,
        size: 22,
        color: scheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DrawerSignOutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _DrawerSignOutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minLeadingWidth: 40,
      horizontalTitleGap: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: scheme.error.withValues(alpha: 0.22),
        ),
      ),
      tileColor: scheme.errorContainer.withValues(alpha: 0.22),
      leading: Icon(
        Icons.logout_rounded,
        size: 22,
        color: scheme.error,
      ),
      title: Text(
        'Sign out',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.error,
        ),
      ),
      subtitle: Text(
        'Leave this account on this device',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.25,
        ),
      ),
      onTap: onTap,
    );
  }
}
