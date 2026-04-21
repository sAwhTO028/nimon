import 'package:flutter/material.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:go_router/go_router.dart';

enum NotificationKind { follow, contentActivity, publish, processing, system }

class AppNotificationV1 {
  const AppNotificationV1({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.whenLabel,
    this.unread = true,
    this.actorHandle,
    this.storyTitle,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String message;
  final String whenLabel;
  final bool unread;

  /// For follow/content activity (V1 routing).
  final String? actorHandle;

  /// For content-related items (V1 placeholder routing).
  final String? storyTitle;

  AppNotificationV1 copyWith({bool? unread}) => AppNotificationV1(
        id: id,
        kind: kind,
        title: title,
        message: message,
        whenLabel: whenLabel,
        unread: unread ?? this.unread,
        actorHandle: actorHandle,
        storyTitle: storyTitle,
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<AppNotificationV1> _items;

  @override
  void initState() {
    super.initState();
    _items = const [
      AppNotificationV1(
        id: 'n1',
        kind: NotificationKind.follow,
        title: 'New follower',
        message: 'Rina followed you',
        whenLabel: 'Just now',
        actorHandle: '@rina_travel',
        unread: true,
      ),
      AppNotificationV1(
        id: 'n2',
        kind: NotificationKind.contentActivity,
        title: 'Saved',
        message: '2 learners saved “雨上がりの駅で”',
        whenLabel: '2h',
        storyTitle: '雨上がりの駅で',
        unread: true,
      ),
      AppNotificationV1(
        id: 'n3',
        kind: NotificationKind.publish,
        title: 'Published',
        message: 'Your story “窓辺のコーヒー” is now published',
        whenLabel: 'Yesterday',
        storyTitle: '窓辺のコーヒー',
        unread: false,
      ),
      AppNotificationV1(
        id: 'n4',
        kind: NotificationKind.processing,
        title: 'Processing finished',
        message: 'Audio for “朝のホームで” finished processing',
        whenLabel: '2d',
        storyTitle: '朝のホームで',
        unread: false,
      ),
      AppNotificationV1(
        id: 'n5',
        kind: NotificationKind.system,
        title: 'System notice',
        message: 'A new update is available (V1 mock)',
        whenLabel: '3d',
        unread: false,
      ),
    ];
  }

  bool get _hasUnread => _items.any((e) => e.unread);

  void _markAllAsRead() {
    setState(() {
      _items = _items.map((e) => e.unread ? e.copyWith(unread: false) : e).toList();
    });
  }

  IconData _kindIcon(NotificationKind k) => switch (k) {
        NotificationKind.follow => Icons.person_add_alt_rounded,
        NotificationKind.contentActivity => Icons.favorite_border_rounded,
        NotificationKind.publish => Icons.public_rounded,
        NotificationKind.processing => Icons.auto_awesome_rounded,
        NotificationKind.system => Icons.info_outline_rounded,
      };

  Color _kindTint(ColorScheme scheme, NotificationKind k) => switch (k) {
        NotificationKind.follow => scheme.primary,
        NotificationKind.contentActivity => scheme.tertiary,
        NotificationKind.publish => scheme.secondary,
        NotificationKind.processing => scheme.primary,
        NotificationKind.system => scheme.onSurfaceVariant,
      };

  void _onTapItem(AppNotificationV1 n) {
    setState(() {
      _items = _items
          .map((e) => e.id == n.id ? e.copyWith(unread: false) : e)
          .toList();
    });

    // V1 routing: keep sensible but lightweight.
    if (n.kind == NotificationKind.follow && (n.actorHandle ?? '').isNotEmpty) {
      final q = Uri.encodeComponent(n.actorHandle!.trim());
      context.push('/profile/public?creator=$q');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open: ${n.title} — coming soon'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const NimonBackButton(),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _items.isEmpty
          ? _EmptyState(scheme: scheme)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = _items[i];
                final tint = _kindTint(scheme, n.kind);
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(
                    alpha: n.unread ? 0.80 : 0.55,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _onTapItem(n),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: tint.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: tint.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Icon(
                                  _kindIcon(n.kind),
                                  size: 20,
                                  color: tint.withValues(alpha: 0.95),
                                ),
                              ),
                              if (n.unread)
                                Positioned(
                                  right: -1,
                                  top: -1,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      n.whenLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.message,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 42,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 14),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'When learners follow you or interact with your content, you’ll see it here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

