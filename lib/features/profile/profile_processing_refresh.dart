import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when local on-disk story drafts used by Profile > Processing change
/// (save, publish, etc.) so the tab can refresh without a tab switch.
///
/// **M5e:** [MonoScreen] also listens so Mono Home refetches `GET /v1/mono/feed` when
/// published catalog surfaces should update (edit entry, remote save on published story, republish).
final profileProcessingListRefreshProvider = StateProvider<int>((ref) => 0);

/// Bump when Trash contents change so [ProfileTrashScreen] can reload while mounted.
final profileTrashListRefreshProvider = StateProvider<int>((ref) => 0);

/// Bump when Saved (bookmarked) contents change so Profile Saved tab can refresh.
final profileSavedListRefreshProvider = StateProvider<int>((ref) => 0);

void bumpProfileCatalogSurfacesRefresh(ProviderContainer container) {
  final n = container.read(profileProcessingListRefreshProvider.notifier);
  n.state = n.state + 1;
}

void bumpPublishedTrashListRefresh(ProviderContainer container) {
  final n = container.read(profileTrashListRefreshProvider.notifier);
  n.state = n.state + 1;
}

void bumpProfileSavedListRefresh(ProviderContainer container) {
  final n = container.read(profileSavedListRefreshProvider.notifier);
  n.state = n.state + 1;
}

/// After trash / restore: Mono Home feed, Workspace/Processing, Published pager,
/// plus Trash list when open.
void bumpPublishedMonoTrashSurfacesRefresh(ProviderContainer container) {
  bumpProfileCatalogSurfacesRefresh(container);
  bumpPublishedTrashListRefresh(container);
}
