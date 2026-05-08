import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../mono/data/mono_feed_item_mapper.dart';
import '../mono/mono_feed_models.dart';
import '../mono/mono_reader_menu_origin.dart';
import 'data/creator_mono_collection.dart';
import 'data/profile_public_providers.dart';
import 'mono_story_list_row.dart';
import 'presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

class OwnerCreatorCollectionDetailArgs {
  const OwnerCreatorCollectionDetailArgs({
    required this.collection,
  });

  final CreatorMonoCollection collection;
}

class OwnerCreatorCollectionDetailScreen extends ConsumerStatefulWidget {
  const OwnerCreatorCollectionDetailScreen({
    super.key,
    required this.args,
  });

  final OwnerCreatorCollectionDetailArgs args;

  @override
  ConsumerState<OwnerCreatorCollectionDetailScreen> createState() =>
      _OwnerCreatorCollectionDetailScreenState();
}

class _OwnerCreatorCollectionDetailScreenState
    extends ConsumerState<OwnerCreatorCollectionDetailScreen> {
  final List<MonoFeedItem> _items = <MonoFeedItem>[];
  String? _nextCursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextCursor = null;
      _hasMore = true;
      _loadingMore = false;
    });
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      final page = await repo.fetchMyCollectionMonos(widget.args.collection.id);
      if (!mounted) return;
      final prof = await ref.read(currentUserPublicProfileProvider.future);
      final wName = prof?.effectiveDisplayName ?? 'Creator';
      final rawH = (prof?.handle ?? '').trim();
      final wHandle =
          rawH.isNotEmpty ? monoWriterHandleDisplay(rawH) : '@reader';
      final wAv = (prof?.avatarUrl ?? '').trim();
      if (!mounted) return;
      setState(() {
        _items.addAll(
          page.items.map(
            (dto) => monoFeedItemFromPublishedMonoListItemDto(
              dto,
              writerName: wName,
              writerHandle: wHandle,
              writerAvatarUrl: wAv.isNotEmpty ? wAv : null,
            ),
          ),
        );
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    final cursor = _nextCursor;
    if (cursor == null || cursor.trim().isEmpty) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      final page = await repo.fetchMyCollectionMonos(
        widget.args.collection.id,
        cursor: cursor,
      );
      if (!mounted) return;
      final prof = await ref.read(currentUserPublicProfileProvider.future);
      final wName = prof?.effectiveDisplayName ?? 'Creator';
      final rawH = (prof?.handle ?? '').trim();
      final wHandle =
          rawH.isNotEmpty ? monoWriterHandleDisplay(rawH) : '@reader';
      final wAv = (prof?.avatarUrl ?? '').trim();
      if (!mounted) return;
      setState(() {
        _items.addAll(
          page.items.map(
            (dto) => monoFeedItemFromPublishedMonoListItemDto(
              dto,
              writerName: wName,
              writerHandle: wHandle,
              writerAvatarUrl: wAv.isNotEmpty ? wAv : null,
            ),
          ),
        );
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _removeFromCollection(String publishedMonoId) async {
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      await repo.removeItem(widget.args.collection.id, publishedMonoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from collection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      unawaited(
        ref.read(myCreatorCollectionsNotifierProvider.notifier).load(),
      );
      unawaited(_loadFirstPage());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showItemMenu(MonoFeedItem it) async {
    final title =
        (it.title ?? '').trim().isEmpty ? 'Untitled' : it.title!.trim();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from collection'),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action == 'remove') {
      await _removeFromCollection(it.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = widget.args.collection.title.trim().isEmpty
        ? 'Untitled'
        : widget.args.collection.title.trim();
    final desc = (widget.args.collection.description ?? '').trim();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: const NimonBackButton(),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desc.isNotEmpty) ...[
                  Text(
                    desc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_loading && _items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && _items.isEmpty) ...[
                  Text(
                    'Could not load collection stories.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadFirstPage,
                    child: const Text('Retry'),
                  ),
                ] else if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No monos in this collection yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      key: ValueKey<String>(
                          'owner_coll_mono_${_items[i].id}_$i'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            context.push(
                              '/mono-reader',
                              extra: <String, Object>{
                                'items': List<MonoFeedItem>.from(_items),
                                'initialIndex': i,
                                'readerMenuOrigin':
                                    MonoReaderMenuOrigin.profileUploaded,
                              },
                            );
                          },
                          child: MonoStoryListRow(
                            title: (_items[i].title ?? '').trim().isEmpty
                                ? 'Untitled'
                                : _items[i].title!.trim(),
                            description:
                                _items[i].storyDescription.trim().isNotEmpty
                                    ? _items[i].storyDescription.trim()
                                    : _items[i].bodyText.trim(),
                            jlptLevel: _items[i].level.trim(),
                            thumbnailUrl: _items[i].coverImageUrl,
                            onMenuTap: () =>
                                unawaited(_showItemMenu(_items[i])),
                          ),
                        ),
                      ),
                    ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: FilledButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(_loadingMore ? 'Loading…' : 'Load more'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
