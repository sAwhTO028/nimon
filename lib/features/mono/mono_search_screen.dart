import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/core/design_system/nimon_layout.dart';
import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';
import 'package:nimon/features/search/mono_search_catalog_facets.dart';
import 'package:nimon/features/search/presentation/mono_search_providers.dart';
import 'package:nimon/features/search/presentation/mono_search_state.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

String? _publishBadgeForRow(MonoFeedItem it) {
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

/// V1 catalog search over published monos (M18C).
class MonoSearchScreen extends ConsumerStatefulWidget {
  const MonoSearchScreen({super.key});

  @override
  ConsumerState<MonoSearchScreen> createState() => _MonoSearchScreenState();
}

class _MonoSearchScreenState extends ConsumerState<MonoSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  DateTime? _lastLoadMoreHint;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _scheduleLoadMore() {
    final now = DateTime.now();
    if (_lastLoadMoreHint != null &&
        now.difference(_lastLoadMoreHint!) <
            const Duration(milliseconds: 450)) {
      return;
    }
    _lastLoadMoreHint = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(monoSearchNotifierProvider.notifier).loadMore());
    });
  }

  bool _onScrollNearEnd(ScrollNotification n, MonoSearchState s) {
    if (n.metrics.axis != Axis.vertical) return false;
    final m = n.metrics;
    if (!m.hasPixels || !m.hasViewportDimension) return false;
    if (!s.canLoadMore) return false;

    final nearEnd =
        m.maxScrollExtent <= 0 ? true : m.pixels >= m.maxScrollExtent - 360;
    if (!nearEnd) return false;

    _scheduleLoadMore();
    return false;
  }

  void _openReader(List<MonoSearchResult> results, int index) {
    final items =
        results.map(monoFeedItemFromMonoSearchResult).toList(growable: false);
    if (items.isEmpty) return;
    final safe = index.clamp(0, items.length - 1);
    context.push(
      '/mono-reader',
      extra: <String, Object?>{
        'items': items,
        'initialIndex': safe,
        'readerMenuOrigin': MonoReaderMenuOrigin.publicCreatorProfile,
      },
    );
  }

  void _clearAll() {
    _queryController.clear();
    unawaited(ref.read(monoSearchNotifierProvider.notifier).clearFilters());
  }

  bool _hasUiFilters(MonoSearchState s) {
    return s.query.trim().isNotEmpty ||
        s.selectedLevel != null ||
        s.selectedCategory != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final s = ref.watch(monoSearchNotifierProvider);
    final notifier = ref.read(monoSearchNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        centerTitle: false,
        leading: const NimonBackButton(),
        actions: [
          if (_hasUiFilters(s))
            IconButton(
              tooltip: l10n.searchClearFiltersTooltip,
              onPressed: _clearAll,
              icon: Icon(
                Icons.clear_all_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      body: NimonReadingColumn.wrap(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _queryController,
                onChanged: notifier.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchInputHint,
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.28),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _FilterChipRow(
              label: l10n.searchLevelLabel,
              children: [
                _nimonChip(
                  context,
                  label: l10n.searchAll,
                  selected: s.selectedLevel == null,
                  onSelected: (_) => unawaited(notifier.setLevel(null)),
                ),
                ...MonoSearchCatalogFacets.jlptLevels.map(
                  (lv) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _nimonChip(
                      context,
                      label: lv,
                      selected: s.selectedLevel == lv,
                      onSelected: (v) =>
                          unawaited(notifier.setLevel(v ? lv : null)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FilterChipRow(
              label: l10n.searchCategoryLabel,
              children: [
                _nimonChip(
                  context,
                  label: l10n.searchAll,
                  selected: s.selectedCategory == null,
                  onSelected: (_) => unawaited(notifier.setCategory(null)),
                ),
                ...MonoSearchCatalogFacets.storyCategories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _nimonChip(
                      context,
                      label: c,
                      selected: s.selectedCategory == c,
                      onSelected: (v) =>
                          unawaited(notifier.setCategory(v ? c : null)),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(l10n.searchLatest),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.28),
                  ),
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _SearchResultsBody(
                state: s,
                onRefresh: () =>
                    ref.read(monoSearchNotifierProvider.notifier).refresh(),
                onRetry: () => unawaited(notifier.refresh()),
                onOpenReader: _openReader,
                onScroll: (n) => _onScrollNearEnd(n, s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: children,
          ),
        ),
      ],
    );
  }
}

Widget _nimonChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required void Function(bool selected) onSelected,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: onSelected,
    selectedColor: scheme.primary.withValues(alpha: 0.22),
    checkmarkColor: scheme.primary,
    labelStyle: theme.textTheme.labelLarge?.copyWith(
      color: selected ? scheme.primary : scheme.onSurface,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
    side: BorderSide(
      color: selected
          ? scheme.primary.withValues(alpha: 0.55)
          : scheme.outline.withValues(alpha: 0.35),
    ),
  );
}

class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onOpenReader,
    required this.onScroll,
  });

  final MonoSearchState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(List<MonoSearchResult> results, int index) onOpenReader;
  final bool Function(ScrollNotification n) onScroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bg = Theme.of(context).colors.appBackground;

    if (state.isLoadingFirstPage && state.items.isEmpty) {
      return ColoredBox(
        color: bg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && !state.isLoadingFirstPage) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.searchErrorTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.error}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.searchRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!state.hasEverFetched &&
        state.items.isEmpty &&
        !state.isLoadingFirstPage) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.searchInitialTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.searchInitialBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.hasEverFetched &&
        state.items.isEmpty &&
        state.error == null &&
        !state.isLoadingFirstPage) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.searchNoResultsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.searchNoResultsBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.28);
    final tail =
        (state.hasMore || state.isLoadingMore) && state.error == null ? 1 : 0;

    return ColoredBox(
      color: bg,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: ListView.separated(
            key: const ValueKey('mono_search_results_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: state.items.length + tail,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: dividerColor,
            ),
            itemBuilder: (ctx, i) {
              if (i >= state.items.length) {
                if (state.isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              }
              final r = state.items[i];
              final feed = monoFeedItemFromMonoSearchResult(r);
              final title =
                  (feed.title ?? '').trim().isNotEmpty ? feed.title! : 'Mono';
              final subtitle = feed.storyDescription.trim();
              final writer = (feed.writerName).trim();
              final likes = formatSocialCount(feed.likesCount);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpenReader(state.items, i),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (writer.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 0, bottom: 2),
                          child: Text(
                            '$writer · ♥ $likes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      MonoStoryListRow(
                        title: title,
                        description: subtitle.isNotEmpty
                            ? subtitle
                            : ' ', // row still shows title/meta
                        jlptLevel: feed.level,
                        thumbnailUrl: feed.coverImageUrl,
                        categoryText: feed.catalogCategory,
                        durationText: feed.readDurationLabel,
                        publishBadgeText: _publishBadgeForRow(feed),
                        onMenuTap: null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
