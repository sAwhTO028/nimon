import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared ephemeral UI state: current Quiz tab selection inside the Create shell.
final quizTabIndexProvider = StateProvider<int>((_) => 0);
