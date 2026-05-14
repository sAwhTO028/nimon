import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/presentation/providers/profile_saved_mono_pager.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';

/// ValueKey prefix for each compact saved row (`$kProfileSavedCompactRowKey$m1`).
const String kProfileSavedCompactRowKey = 'profileSavedCompactRow_';

/// ValueKey prefix for unsave control (`$kProfileSavedUnsaveButtonKey$m1`).
const String kProfileSavedUnsaveButtonKey = 'profileSavedUnsave_';

String? publishBadgeLabelForMonoFeedItem(MonoFeedItem it) {
  final p = it.publishedAccess;
  if (p == null) return null;
  if (p.isFullLearnPublished) {
    return publishBadgeLabel(PublishedDisplayKind.fullLearn);
  }
  if (p.isReadOnlyPublished) {
    return publishBadgeLabel(PublishedDisplayKind.readOnly);
  }
  return null;
}

/// Remote Profile **Saved** tab (`GET /v1/me/bookmarks`).
class ProfileSavedRemoteTab extends ConsumerStatefulWidget {
  const ProfileSavedRemoteTab({super.key, required this.bottomPadding});

  final double bottomPadding;

  @override
  ConsumerState<ProfileSavedRemoteTab> createState() =>
      _ProfileSavedRemoteTabState();
}

class _ProfileSavedRemoteTabState extends ConsumerState<ProfileSavedRemoteTab> {
  bool _booted = false;

  void _ensureLoaded() {
    if (_booted) return;
    _booted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(profileSavedMonoPagerProvider.notifier).loadFirstPage(),
      );
    });
  }

  Future<void> _openReader(List<MonoFeedItem> list, int idx) async {
    final safe = idx.clamp(0, list.length - 1);
    if (!context.mounted) return;
    context.push(
      '/mono-reader',
      extra: <String, Object?>{
        'items': list,
        'initialIndex': safe,
        'readerMenuOrigin': MonoReaderMenuOrigin.profileSaved,
        'onUnsavedMonoFeedItemId': (String monoId) {
          ref
              .read(profileSavedMonoPagerProvider.notifier)
              .removeItemsByIds({monoId});
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider);

    if (session is! AuthSessionAuthenticated) {
      return ColoredBox(
        color: Theme.of(context).colors.appBackground,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SavedLibraryCopy.guestTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  SavedLibraryCopy.guestBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    _ensureLoaded();

    final ps = ref.watch(profileSavedMonoPagerProvider);
    final items = ps.items;

    if (items.isEmpty && ps.isInitialLoading && ps.error == null) {
      return ColoredBox(
        color: Theme.of(context).colors.appBackground,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (items.isEmpty && ps.error != null && !ps.isInitialLoading) {
      return ColoredBox(
        color: Theme.of(context).colors.appBackground,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load saved stories.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${ps.error}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => unawaited(
                    ref
                        .read(profileSavedMonoPagerProvider.notifier)
                        .loadFirstPage(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (items.isEmpty && ps.error == null && !ps.isInitialLoading) {
      return ColoredBox(
        color: Theme.of(context).colors.appBackground,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  SavedLibraryCopy.emptyTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  SavedLibraryCopy.emptyBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dividerColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Theme.of(context).colors.appBackground,
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(profileSavedMonoPagerProvider.notifier).refresh(),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
          itemCount: items.length + (ps.canLoadMore ? 1 : 0),
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
          ),
          itemBuilder: (ctx, i) {
            if (i >= items.length) {
              unawaited(
                ref.read(profileSavedMonoPagerProvider.notifier).loadMore(),
              );
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final it = items[i];
            final title =
                (it.title ?? '').trim().isNotEmpty ? it.title! : 'Mono';
            final subtitle = it.storyDescription.trim();
            return Material(
              key: ValueKey('$kProfileSavedCompactRowKey${it.id}'),
              color: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(_openReader(items, i)),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MonoStoryListRow(
                        title: title,
                        description: subtitle,
                        jlptLevel: it.level,
                        thumbnailUrl: it.coverImageUrl,
                        publishBadgeText: publishBadgeLabelForMonoFeedItem(it),
                        onMenuTap: null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        key: ValueKey('$kProfileSavedUnsaveButtonKey${it.id}'),
                        tooltip: SavedLibraryCopy.removeFromSavedTooltip,
                        icon: Icon(
                          Icons.bookmark_remove_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final container =
                              ProviderScope.containerOf(context, listen: false);
                          try {
                            await ref
                                .read(remoteMonoSocialRepositoryProvider)
                                .unbookmarkMono(it.monoIdForLearnRoutes);
                            if (!context.mounted) return;
                            ref
                                .read(profileSavedMonoPagerProvider.notifier)
                                .removeItemsByIds({it.id});
                            bumpProfileSavedListRefresh(container);
                          } catch (e) {
                            if (!context.mounted) return;
                            final msg = e is StateError ? e.message : '$e';
                            messenger.showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
