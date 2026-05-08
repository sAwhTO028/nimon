import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/published_mono_catalog_visibility_exception.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/features/profile/presentation/permanent_delete_confirm_dialog.dart';
import 'package:nimon/features/profile/presentation/providers/profile_trashed_published_mono_pager.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Owner Trash list for published monos (`GET /v1/published-monos?trashed=true`).
class ProfileTrashScreen extends ConsumerStatefulWidget {
  const ProfileTrashScreen({super.key});

  @override
  ConsumerState<ProfileTrashScreen> createState() => _ProfileTrashScreenState();
}

class _ProfileTrashScreenState extends ConsumerState<ProfileTrashScreen> {
  ProviderSubscription<int>? _trashBumpSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (RemoteBackendConfig.useRemoteDrafts) {
        unawaited(
          ref
              .read(profileTrashedPublishedMonoPagerProvider.notifier)
              .loadFirstPage(),
        );
      }
    });
    _trashBumpSub =
        ref.listenManual<int>(profileTrashListRefreshProvider, (prev, next) {
      if (!mounted) return;
      if (!RemoteBackendConfig.useRemoteDrafts) return;
      unawaited(
        ref.read(profileTrashedPublishedMonoPagerProvider.notifier).refresh(),
      );
    });
  }

  @override
  void dispose() {
    _trashBumpSub?.close();
    super.dispose();
  }

  Future<void> _onRestore(
    PublishedMonoListItemDto row,
    RemotePublishedMonoRepository repo,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore story?'),
        content: const Text(
          'This story will return to Published if it has no unpublished edits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    try {
      await repo.restorePublishedMono(row.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }

    if (!mounted) return;
    bumpPublishedMonoTrashSurfacesRefresh(
      ProviderScope.containerOf(context, listen: false),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restored.')),
    );

    var dirtyCatalog = false;
    try {
      await repo.get(row.id);
    } catch (e) {
      if (e is PublishedMonoHiddenWhileEditingException) {
        dirtyCatalog = true;
      }
    }
    if (!mounted) return;
    if (dirtyCatalog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restored. It will appear after you update the published version.',
          ),
        ),
      );
    }
  }

  Future<void> _onPermanentDelete(
    PublishedMonoListItemDto row,
    RemotePublishedMonoRepository repo,
  ) async {
    final step1 = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently delete story?'),
        content: const Text(
          'This will permanently delete the published story and its draft. '
          'This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('permanentDeleteContinue'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final step2 = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const PermanentDeleteTypedConfirmDialog(),
    );
    if (step2 != true || !mounted) return;

    try {
      await repo.permanentlyDeletePublishedMono(row.id);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // For 404 already-deleted, refresh so the row disappears.
      if (msg.contains('already deleted')) {
        bumpPublishedMonoTrashSurfacesRefresh(
          ProviderScope.containerOf(context, listen: false),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story was already deleted.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    if (!mounted) return;
    bumpPublishedMonoTrashSurfacesRefresh(
      ProviderScope.containerOf(context, listen: false),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted permanently.')),
    );
  }

  static String _movedSubtitle(PublishedMonoListItemDto row) {
    final raw =
        ((row.trashedAt ?? '').trim().isEmpty ? row.updatedAt : row.trashedAt)
            ?.trim();
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return 'Moved to Trash';
    }
    final local = dt.toLocal();
    final formatted = DateFormat.yMMMd().add_jm().format(local);
    return 'Moved to Trash · $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pager = ref.watch(profileTrashedPublishedMonoPagerProvider);
    final useRemote = RemoteBackendConfig.useRemoteDrafts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        leading: NimonBackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
      ),
      body: !useRemote
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Trash is available when remote drafts are enabled.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : pager.isInitialLoading && pager.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : pager.error != null && pager.items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pager.error!.toString(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                unawaited(
                                  ref
                                      .read(
                                          profileTrashedPublishedMonoPagerProvider
                                              .notifier)
                                      .refresh(),
                                );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : pager.items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 48,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Trash is empty',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Stories you move to Trash will appear here.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(profileTrashedPublishedMonoPagerProvider
                                  .notifier)
                              .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: pager.items.length +
                                (pager.canLoadMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= pager.items.length) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: pager.isLoadingMore
                                        ? const SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: () {
                                              unawaited(
                                                ref
                                                    .read(
                                                      profileTrashedPublishedMonoPagerProvider
                                                          .notifier,
                                                    )
                                                    .loadMore(),
                                              );
                                            },
                                            child: const Text('Load more'),
                                          ),
                                  ),
                                );
                              }
                              final row = pager.items[index];
                              final repo = ref.read(
                                  remotePublishedMonoRepositoryForProfileProvider);
                              final subtitle = _movedSubtitle(row);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Material(
                                  color: scheme.surface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: _TrashCover(
                                              url: row.coverImageUrl,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                row.title.trim().isEmpty
                                                    ? 'Untitled'
                                                    : row.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                alignment: WrapAlignment.end,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  FilledButton.tonal(
                                                    onPressed: () => unawaited(
                                                      _onRestore(row, repo),
                                                    ),
                                                    child:
                                                        const Text('Restore'),
                                                  ),
                                                  TextButton(
                                                    key: ValueKey(
                                                      'permanentDelete_${row.id}',
                                                    ),
                                                    onPressed: () => unawaited(
                                                      _onPermanentDelete(
                                                        row,
                                                        repo,
                                                      ),
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          scheme.error,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    child: const Text(
                                                      'Permanently delete',
                                                    ),
                                                  ),
                                                ],
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
                        ),
    );
  }
}

class _TrashCover extends StatelessWidget {
  const _TrashCover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u != null && u.isNotEmpty) {
      return Image.network(
        u,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _TrashCoverPlaceholder(),
      );
    }
    return const _TrashCoverPlaceholder();
  }
}

class _TrashCoverPlaceholder extends StatelessWidget {
  const _TrashCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image_outlined,
        color: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}
