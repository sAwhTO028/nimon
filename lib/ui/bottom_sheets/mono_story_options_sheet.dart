import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/create/creator_resume_draft.dart';
import 'package:nimon/features/mono/mono_reader_dock.dart';
import 'package:nimon/features/mono/mono_feed_item_detail_metrics.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/features/mono/saved_only_ux_policy.dart';
import 'package:nimon/features/mono/share_mono_link.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/features/profile/profile_processing_refresh.dart';

OverlayEntry? _monoStoryOptionsOverlay;
ScrollController? _monoStoryOptionsScrollController;
String? _monoStoryOptionsStoryId;

/// True while the reader dock story-options overlay is shown; used so system Back
/// dismisses this panel before route pop ([PopScope] on [MonoScreen]).
final ValueNotifier<bool> monoReaderStoryOptionsOpen = ValueNotifier(false);

void hideMonoStoryOptionsPanel() {
  _monoStoryOptionsOverlay?.remove();
  _monoStoryOptionsOverlay = null;
  _monoStoryOptionsStoryId = null;
  _monoStoryOptionsScrollController?.dispose();
  _monoStoryOptionsScrollController = null;
  monoReaderStoryOptionsOpen.value = false;
}

bool get isMonoStoryOptionsPanelOpen => _monoStoryOptionsOverlay != null;

/// Dock-anchored floating panel that appears **above** the reader dock.
/// This intentionally keeps the dock visible and uncovered.
void showMonoStoryOptionsPanel(
  BuildContext context,
  MonoFeedItem item, {
  MonoReaderMenuOrigin readerMenuOrigin = MonoReaderMenuOrigin.profileUploaded,
  void Function(String monoFeedItemId)? onUnsavedItemId,
  VoidCallback? popReaderAfterUnsave,
  @visibleForTesting bool? demoBookmarkFoldersOverrideForTest,
}) {
  final showDemoBookmarkFolders =
      demoBookmarkFoldersOverrideForTest ?? monoDemoBookmarkFoldersEnabled;
  // Toggle behavior: tapping menu again closes the panel.
  if (isMonoStoryOptionsPanelOpen && _monoStoryOptionsStoryId == item.id) {
    hideMonoStoryOptionsPanel();
    HapticFeedback.selectionClick();
    return;
  }

  hideMonoStoryOptionsPanel();

  final overlay = Overlay.of(context);

  final dockH = MonoReaderDock.occupiedHeight(context);
  final mq = MediaQuery.of(context);
  final availableH = (mq.size.height - dockH).clamp(0.0, double.infinity);
  // Keep this panel compact (bottom-sheet feel), not dialog-tall.
  final maxPanelH = math.min(availableH * 0.72, 420.0);

  // Small gap so it feels attached to the dock edge.
  const gapAboveDock = 10.0;

  _monoStoryOptionsStoryId = item.id;
  final scrollController = ScrollController();
  _monoStoryOptionsScrollController = scrollController;

  _monoStoryOptionsOverlay = OverlayEntry(
    builder: (ctx) {
      return Stack(
        children: [
          // Dim only ABOVE the dock so the dock remains clearly present.
          Positioned.fill(
            bottom: dockH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hideMonoStoryOptionsPanel,
              child: Container(
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: dockH + gapAboveDock,
            child: _DismissibleDockPanel(
              maxHeight: maxPanelH,
              scrollController: scrollController,
              onDismiss: hideMonoStoryOptionsPanel,
              child: _MonoStoryOptionsContent(
                item: item,
                hostContextForActions: context,
                controller: scrollController,
                onClose: hideMonoStoryOptionsPanel,
                readerMenuOrigin: readerMenuOrigin,
                onUnsavedItemId: onUnsavedItemId,
                popReaderAfterUnsave: popReaderAfterUnsave,
                showDemoBookmarkFolders: showDemoBookmarkFolders,
                demoBookmarkFoldersOverrideForTest:
                    demoBookmarkFoldersOverrideForTest,
              ),
            ),
          ),
          // Leave the dock area untouched (no dim, no gesture capture).
          // (Intentionally no overlay widget in the dock zone.)
        ],
      );
    },
  );

  overlay.insert(_monoStoryOptionsOverlay!);
  monoReaderStoryOptionsOpen.value = true;

  HapticFeedback.selectionClick();
}

class _DismissibleDockPanel extends StatefulWidget {
  final double maxHeight;
  final ScrollController scrollController;
  final VoidCallback onDismiss;
  final Widget child;

  const _DismissibleDockPanel({
    required this.maxHeight,
    required this.scrollController,
    required this.onDismiss,
    required this.child,
  });

  @override
  State<_DismissibleDockPanel> createState() => _DismissibleDockPanelState();
}

class _DismissibleDockPanelState extends State<_DismissibleDockPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  double _dragDy = 0;
  bool _dragging = false;

  bool get _canStartDismissDrag {
    if (!widget.scrollController.hasClients) return true;
    return widget.scrollController.offset <= 0.0;
  }

  void _animateBack() {
    final start = _dragDy;
    _settle
      ..value = 0
      ..removeListener(_tickBack);
    void tick() {
      setState(() {
        _dragDy = start * (1.0 - _settle.value);
      });
    }

    _tickBack = tick;
    _settle.addListener(_tickBack);
    _settle.forward(from: 0).whenComplete(() {
      _settle.removeListener(_tickBack);
      _dragDy = 0;
    });
  }

  VoidCallback _tickBack = () {};

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final clampedDy = _dragDy.clamp(0.0, 260.0);
    final t = (clampedDy / 220.0).clamp(0.0, 1.0);
    final fade = (1.0 - (t * 0.35)).clamp(0.65, 1.0);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) {
          if (!_canStartDismissDrag) return;
          setState(() {
            _dragging = true;
          });
        },
        onVerticalDragUpdate: (d) {
          if (!_dragging) return;
          if (!_canStartDismissDrag) return;
          final next = _dragDy + d.delta.dy;
          setState(() {
            _dragDy = next < 0 ? 0 : next;
          });
        },
        onVerticalDragEnd: (d) {
          if (!_dragging) return;
          _dragging = false;
          final v = d.primaryVelocity ?? 0.0;
          final shouldDismiss = _dragDy > 86 || v > 820;
          if (shouldDismiss) {
            widget.onDismiss();
          } else {
            _animateBack();
          }
        },
        child: AnimatedOpacity(
          opacity: fade,
          duration: const Duration(milliseconds: 80),
          child: Transform.translate(
            offset: Offset(0, clampedDy),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Natural height up to max; don't force full height.
                maxHeight: widget.maxHeight,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonoStoryOptionsContent extends StatelessWidget {
  final MonoFeedItem item;

  /// Context below the overlay (e.g. [MonoScreen]) — still mounted after the panel closes.
  final BuildContext hostContextForActions;
  final ScrollController controller;
  final VoidCallback? onClose;
  final MonoReaderMenuOrigin readerMenuOrigin;
  final void Function(String monoFeedItemId)? onUnsavedItemId;
  final VoidCallback? popReaderAfterUnsave;
  final bool showDemoBookmarkFolders;
  final bool? demoBookmarkFoldersOverrideForTest;

  const _MonoStoryOptionsContent({
    required this.item,
    required this.hostContextForActions,
    required this.controller,
    this.onClose,
    required this.readerMenuOrigin,
    this.onUnsavedItemId,
    this.popReaderAfterUnsave,
    required this.showDemoBookmarkFolders,
    this.demoBookmarkFoldersOverrideForTest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // In a floating panel above the dock, we don't need safe-area bottom padding.
    const bottomPadding = 0.0;

    final title = (item.title ?? '').trim().isNotEmpty
        ? item.title!.trim()
        : 'Mono Story';
    final subtitle = _subtitleFor(item);
    final basicsDescription = item.storyDescription.trim();
    final likesLabel = monoDetailSheetLikesValue(item);
    final readTime = monoDetailSheetReadTimeValue(item);
    final category = monoDetailSheetCategoryValue(item);

    return Container(
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Handle (matching sheet language, but inside the floating panel)
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(
                    item: item,
                    title: title,
                    subtitle: subtitle,
                    onShare: () {
                      unawaited(shareMonoLink(hostContextForActions, item));
                    },
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                    color: colorScheme.outlineVariant,
                  ),
                  if (basicsDescription.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: _DescriptionCard(text: basicsDescription),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _MetricsRow(
                      likesLabel: likesLabel,
                      readTime: readTime,
                      category: category,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 6,
              bottom: bottomPadding + 6,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: readerMenuOrigin == MonoReaderMenuOrigin.profileSaved
                ? showDemoBookmarkFolders
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onClose?.call();
                                onUnsavedItemId?.call(item.id);
                                popReaderAfterUnsave?.call();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Unsave'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onClose?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Move - Coming soon'),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Move'),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onClose?.call();
                            onUnsavedItemId?.call(item.id);
                            popReaderAfterUnsave?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            SavedLibraryCopy.removeFromSavedCta,
                          ),
                        ),
                      )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('movePublishedMonoToTrash'),
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            final publishedId =
                                item.monoIdForLearnRoutes.trim();
                            final host = hostContextForActions;
                            final hostMessenger = ScaffoldMessenger.of(host);
                            if (publishedId.isEmpty) {
                              hostMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This story cannot be moved to Trash right now.',
                                  ),
                                ),
                              );
                              return;
                            }

                            // Close this dock panel before showing a dialog; otherwise
                            // the dialog can appear behind the overlay.
                            onClose?.call();
                            await Future<void>.delayed(Duration.zero);
                            if (!host.mounted) return;

                            final go = await showDialog<bool>(
                              context: host,
                              useRootNavigator: true,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Move to Trash?'),
                                content: const Text(
                                  'This story will be hidden from Mono Home and your '
                                  'Published tab. You can restore it later.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    key: const ValueKey(
                                      'confirmMovePublishedMonoToTrash',
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Move to Trash'),
                                  ),
                                ],
                              ),
                            );
                            if (!host.mounted) return;
                            if (go != true) {
                              // Restore the sheet on cancel.
                              showMonoStoryOptionsPanel(
                                host,
                                item,
                                readerMenuOrigin: readerMenuOrigin,
                                onUnsavedItemId: onUnsavedItemId,
                                popReaderAfterUnsave: popReaderAfterUnsave,
                                demoBookmarkFoldersOverrideForTest:
                                    demoBookmarkFoldersOverrideForTest,
                              );
                              return;
                            }

                            final container = ProviderScope.containerOf(
                              host,
                              listen: false,
                            );
                            final repo = container.read(
                              remotePublishedMonoRepositoryForProfileProvider,
                            );
                            try {
                              await repo.trashPublishedMono(publishedId);
                              bumpPublishedMonoTrashSurfacesRefresh(container);
                              await container
                                  .read(profilePublishedMonoPagerProvider
                                      .notifier)
                                  .refresh();
                              if (!host.mounted) return;
                              hostMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Moved to Trash.'),
                                ),
                              );
                              // If user is in the Profile published reader route,
                              // return to the list surface after trash.
                              if (Navigator.of(host).canPop()) {
                                Navigator.of(host).maybePop();
                              }
                            } catch (e) {
                              if (!host.mounted) return;
                              hostMessenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Move to Trash'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            backgroundColor: const Color(0xFFDF3B3B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            if (kDebugMode) {
                              debugPrint(
                                '[PublishedEdit] dock Edit tap item.id=${item.id} '
                                'sourceDraftId=${item.sourceDraftId} '
                                'catalogMonoId=${item.catalogMonoId} '
                                'hostMounted=${hostContextForActions.mounted}',
                              );
                            }
                            onClose?.call();
                            if (!hostContextForActions.mounted) return;
                            await CreatorDraftResumeFlow
                                .tryResumeFromPublishedSurface(
                              hostContextForActions,
                              item.id,
                              sourceDraftId: item.sourceDraftId,
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _subtitleFor(MonoFeedItem item) {
    final handle = item.writerHandle.trim();
    final who = '${item.writerName}${handle.isNotEmpty ? ' $handle' : ''}';
    return who;
  }
}

class _Header extends StatelessWidget {
  final MonoFeedItem item;
  final String title;
  final String subtitle;
  final VoidCallback onShare;

  const _Header({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverThumb(item: item),
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
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          fontSize: 16.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _JlptChip(level: item.level),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              onShare();
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 30),
                            ),
                            child: Icon(
                              Icons.ios_share_rounded,
                              size: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final MonoFeedItem item;
  const _CoverThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(14);
    final url = item.coverImageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        width: 66,
        height: 66,
        child: hasUrl
            ? Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              )
            : ColoredBox(
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
      ),
    );
  }
}

class _JlptChip extends StatelessWidget {
  final String level;
  const _JlptChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          level,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String text;
  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final String likesLabel;
  final String readTime;
  final String category;

  const _MetricsRow({
    required this.likesLabel,
    required this.readTime,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.favorite,
              value: likesLabel,
              caption: 'Likes',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              icon: Icons.access_time,
              value: readTime,
              caption: 'Read time',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              icon: Icons.bookmark_outline,
              value: category,
              caption: 'Category',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String caption;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.caption,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
