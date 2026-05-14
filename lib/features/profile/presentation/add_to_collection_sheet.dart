import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/protected_action.dart';
import 'package:nimon/core/validation/protected_action_guard.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/data/published_mono_id_sanitizer.dart';
import 'package:nimon/core/validation/collection_validators.dart';
import 'package:nimon/core/validation/form_validation_adapter.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/features/profile/presentation/widgets/profile_collection_bottom_sheet_frame.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';

/// Widget test / accessibility key for the "N selected" line (M14G).
const ValueKey<String> collectionSheetSelectedCountTextKey =
    ValueKey('collectionSheetSelectedCountText');

/// Returns `true` when stories were added to a collection (sheet pops successfully).
Future<bool> showAddToCollectionSheet({
  required BuildContext context,
  required List<String> publishedMonoIds,
  AddToCollectionSheetMode mode = AddToCollectionSheetMode.createAndAdd,
  bool startInCreateMode = false,
}) async {
  if (!await ensureProtectedActionAllowed(
    context,
    action: ProtectedActionType.createCollection,
  )) {
    return false;
  }
  if (!context.mounted) return false;
  final out = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProfileCollectionBottomSheetFrame(
      child: _AddToCollectionSheetBody(
        publishedMonoIds: publishedMonoIds,
        mode: mode,
        startInCreateMode: startInCreateMode,
      ),
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
  ValidationIssue? _nameIssue;

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
    } on AppQuotaExceededException catch (e) {
      if (!mounted) return;
      await showQuotaExceededDialog(context, e);
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
    final nameRes = validateCollectionName(_nameController.text);
    final nameErr = firstBlockingIssueForField(nameRes, 'collection.title');
    if (nameErr != null) {
      setState(() => _nameIssue = nameErr);
      return;
    }
    setState(() => _nameIssue = null);
    final name = _nameController.text.trim();
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
    } on AppQuotaExceededException catch (e) {
      if (!mounted) return;
      await showQuotaExceededDialog(context, e);
    } on HttpValidationFailedException catch (e) {
      if (!mounted) return;
      final byField = blockingIssuesByField(e.issues);
      final mapped = byField['collection.title'] ?? byField['collection.name'];
      final extra = firstUnhandledBlockingIssue(e.issues, byField.keys.toSet());
      final shownIssue = mapped ?? extra;
      setState(() => _nameIssue = shownIssue);
      if (shownIssue == null && e.issues.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              validationIssueDisplayMessageLocalized(
                context,
                e.issues.first,
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    final scheme = theme.colorScheme;
    final state = ref.watch(myCreatorCollectionsNotifierProvider);
    final count =
        PublishedMonoIdSanitizer.sanitize(widget.publishedMonoIds).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.mode == AddToCollectionSheetMode.createAndAdd
              ? 'Move to collection'
              : 'New collection',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$count selected',
          key: collectionSheetSelectedCountTextKey,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (_creating) ...[
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Collection name',
              border: const OutlineInputBorder(),
              errorText: _nameIssue != null
                  ? validationIssueDisplayMessageLocalized(
                      context,
                      _nameIssue!,
                    )
                  : null,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_nameIssue != null) setState(() => _nameIssue = null);
            },
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
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
                                  color: scheme.onSurface,
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
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${c.itemCount} stor${c.itemCount == 1 ? 'y' : 'ies'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
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
    );
  }
}
