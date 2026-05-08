import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/data/published_mono_id_sanitizer.dart';

/// Returns `true` when stories were added to a collection (sheet pops successfully).
Future<bool> showAddToCollectionSheet({
  required BuildContext context,
  required List<String> publishedMonoIds,
  AddToCollectionSheetMode mode = AddToCollectionSheetMode.createAndAdd,
  bool startInCreateMode = false,
}) async {
  final out = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AddToCollectionSheetBody(
      publishedMonoIds: publishedMonoIds,
      mode: mode,
      startInCreateMode: startInCreateMode,
    ),
  );
  return out ?? false;
}

enum AddToCollectionSheetMode {
  /// Create a collection, then bulk-add the selected PublishedMono ids.
  createAndAdd,

  /// Create an empty collection (no bulk add).
  createOnly,
}

class _AddToCollectionSheetBody extends ConsumerStatefulWidget {
  const _AddToCollectionSheetBody({
    required this.publishedMonoIds,
    required this.mode,
    required this.startInCreateMode,
  });

  final List<String> publishedMonoIds;
  final AddToCollectionSheetMode mode;
  final bool startInCreateMode;

  @override
  ConsumerState<_AddToCollectionSheetBody> createState() =>
      _AddToCollectionSheetBodyState();
}

class _AddToCollectionSheetBodyState
    extends ConsumerState<_AddToCollectionSheetBody> {
  final TextEditingController _nameController = TextEditingController();
  bool _creating = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _creating = widget.startInCreateMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(myCreatorCollectionsNotifierProvider.notifier).load(),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _userMessage(Object e) {
    final s = e.toString();
    return s.replaceFirst(RegExp(r'^Bad state:\s*'), '').trim();
  }

  Future<void> _bulkAddTo(String collectionId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref
          .read(myCreatorCollectionsNotifierProvider.notifier)
          .bulkAddToCollection(
            collectionId: collectionId,
            publishedMonoIds: widget.publishedMonoIds,
          );
      if (!mounted) return;
      if (r.inserted > 0) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Added to collection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (r.skippedDuplicates > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Already in collection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (r.skippedNotOwnedOrMissing > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Some stories could not be added.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_userMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitCreateAndMaybeAdd() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter a collection name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final sanitizedIds =
        PublishedMonoIdSanitizer.sanitize(widget.publishedMonoIds);
    final wantsAdd = widget.mode == AddToCollectionSheetMode.createAndAdd;
    if (wantsAdd && sanitizedIds.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Stories are still syncing. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    if (kDebugMode) {
      debugPrint('[AddToCollectionSheet] create tapped');
      debugPrint(
        '[AddToCollectionSheet] mode=${widget.mode} ids=${sanitizedIds.length}',
      );
      debugPrint('[AddToCollectionSheet] creating collection title="$name"');
    }
    try {
      final created = await ref
          .read(myCreatorCollectionsNotifierProvider.notifier)
          .createCollection(name);
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint(
            '[AddToCollectionSheet] created collection id=${created.id}');
      }
      if (widget.mode == AddToCollectionSheetMode.createOnly) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Collection created.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _creating = false);
      _nameController.clear();
      if (kDebugMode) {
        debugPrint(
          '[AddToCollectionSheet] bulk adding ids=${sanitizedIds.length}',
        );
      }
      await _bulkAddTo(created.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_userMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final state = ref.watch(myCreatorCollectionsNotifierProvider);
    final count =
        PublishedMonoIdSanitizer.sanitize(widget.publishedMonoIds).length;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 16 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.mode == AddToCollectionSheetMode.createAndAdd
                ? 'Move to collection'
                : 'New collection',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_creating) ...[
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Collection name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submitCreateAndMaybeAdd()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _creating = false;
                              _nameController.clear();
                            }),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => unawaited(_submitCreateAndMaybeAdd()),
                    child: Text(_submitting ? 'Creating…' : 'Create'),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              height: math.min(
                360.0,
                MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: state.isLoading && state.collections.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : state.error != null && state.collections.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _userMessage(state.error!),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => ref
                                  .read(myCreatorCollectionsNotifierProvider
                                      .notifier)
                                  .load(),
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : state.collections.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  'No collections yet.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: state.collections.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final c = state.collections[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    c.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${c.itemCount} stor${c.itemCount == 1 ? 'y' : 'ies'}',
                                  ),
                                  onTap: () => unawaited(_bulkAddTo(c.id)),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _creating = true),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create new collection'),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
