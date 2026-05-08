import 'dart:convert';

import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRoSigPrefix = 'nimon_ro_published_core_sig_v1_';
String _kRoSigKey(String draftId) => '$_kRoSigPrefix${draftId.trim()}';

/// Deterministic signature of the **Read Only** published content (story core).
///
/// V1 intent: detect "edited after Read Only publish" without changing publishState
/// semantics or requiring server timestamps.
String computeReadOnlyPublishedCoreSignature(CreatorStoryV1 d) {
  final basics = d.basics;
  final payload = <String, Object?>{
    'title': basics.title.trim(),
    'category': basics.category.trim(),
    'level': basics.level.trim(),
    'description': basics.description.trim(),
    // Publish-critical core is basics + sentences; promptSourceNote/cover are ignored for now.
    'sentences': [for (final s in d.sentences) s.japaneseText.trim()],
  };
  return base64Url.encode(utf8.encode(jsonEncode(payload)));
}

Future<String?> loadReadOnlyPublishedCoreSignature(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return null;
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_kRoSigKey(id));
  return v?.trim().isEmpty == true ? null : v?.trim();
}

Future<void> saveReadOnlyPublishedCoreSignature({
  required String draftId,
  required String signature,
}) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final sig = signature.trim();
  if (sig.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.setString(_kRoSigKey(id), sig);
}

Future<void> clearReadOnlyPublishedCoreSignature(String draftId) async {
  final id = draftId.trim();
  if (id.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  await p.remove(_kRoSigKey(id));
}
