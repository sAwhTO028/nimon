import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when local on-disk story drafts used by Profile > Processing change
/// (save, publish, etc.) so the tab can refresh without a tab switch.
final profileProcessingListRefreshProvider = StateProvider<int>((ref) => 0);
