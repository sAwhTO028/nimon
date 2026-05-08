import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Route extra for [PublicCreatorCollectionDetailScreen] (no public GET-one endpoint).
class PublicCreatorCollectionDetailArgs {
  const PublicCreatorCollectionDetailArgs({
    required this.userId,
    required this.collection,
    required this.writerDisplayName,
    required this.writerHandle,
    this.writerAvatarUrl,
  });

  final String userId;
  final CreatorMonoCollection collection;

  /// Display name for mapped [MonoFeedItem.writerName].
  final String writerDisplayName;

  /// Handle text for [MonoFeedItem.writerHandle] (include `@` when applicable).
  final String writerHandle;

  /// Optional avatar URL from public profile (M9f).
  final String? writerAvatarUrl;
}

class PublicCreatorCollectionDetailScreen extends ConsumerStatefulWidget {
  const PublicCreatorCollectionDetailScreen({
    super.key,
    required this.args,
  });

  final PublicCreatorCollectionDetailArgs args;

  @override
  ConsumerState<PublicCreatorCollectionDetailScreen> createState() =>
      _PublicCreatorCollectionDetailScreenState();
}

class _PublicCreatorCollectionDetailScreenState
    extends ConsumerState<PublicCreatorCollectionDetailScreen> {
  final List<MonoFeedItem> _items = <MonoFeedItem>[];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadFirstPage());
    });
  }

  Future<void> _loadFirstPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextCursor = null;
      _hasMore = false;
    });
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      final page = await repo.fetchPublicCollectionMonos(
        widget.args.userId,
        widget.args.collection.id,
        limit: 24,
      );
      if (!mounted) return;
      final a = widget.args;
      setState(() {
        _items.addAll(
          page.items.map(
            (dto) => monoFeedItemFromPublishedMonoListItemDto(
              dto,
              writerName: a.writerDisplayName,
              writerHandle: a.writerHandle,
              writerAvatarUrl: a.writerAvatarUrl,
            ),
          ),
        );
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final c = _nextCursor;
    if (c == null || c.trim().isEmpty) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final repo = ref.read(remoteCreatorCollectionsRepositoryProvider);
      final page = await repo.fetchPublicCollectionMonos(
        widget.args.userId,
        widget.args.collection.id,
        cursor: c,
        limit: 24,
      );
      if (!mounted) return;
      final a = widget.args;
      setState(() {
        _items.addAll(
          page.items.map(
            (dto) => monoFeedItemFromPublishedMonoListItemDto(
              dto,
              writerName: a.writerDisplayName,
              writerHandle: a.writerHandle,
              writerAvatarUrl: a.writerAvatarUrl,
            ),
          ),
        );
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final desc = (widget.args.collection.description ?? '').trim();
    final title = widget.args.collection.title.trim().isEmpty
        ? 'Collection'
        : widget.args.collection.title.trim();

    Widget bodyContent() {
      if (_loading && _items.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (_error != null && _items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
            ],
          ),
        );
      }
      if (_items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No monos in this collection yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      }

      final children = <Widget>[
        for (var i = 0; i < _items.length; i++)
          Padding(
            key: ValueKey<String>('coll_mono_${_items[i].id}_$i'),
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
                          MonoReaderMenuOrigin.publicCreatorProfile,
                    },
                  );
                },
                child: MonoStoryListRow(
                  title: (_items[i].title ?? '').trim().isEmpty
                      ? 'Untitled'
                      : _items[i].title!.trim(),
                  description: _items[i].storyDescription.trim().isNotEmpty
                      ? _items[i].storyDescription.trim()
                      : _items[i].bodyText.trim(),
                  jlptLevel: _items[i].level.trim(),
                  thumbnailUrl: _items[i].coverImageUrl,
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
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    desc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              bodyContent(),
            ],
          ),
        ),
      ),
    );
  }
}
