import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short progress line while remote publish runs (e.g. two-step Full Learn).
///
/// Cleared when publish completes or fails (`creator_drawer_publish`).
final creatorPublishStatusTextProvider = StateProvider<String?>((ref) => null);
