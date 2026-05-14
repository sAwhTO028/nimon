import 'package:characters/characters.dart';

String trimText(String? value) => value == null ? '' : value.trim();

String collapseSpaces(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

String normalizeSingleLineText(String value) {
  final t = trimText(value);
  final noBreaks = t.replaceAll(RegExp(r'[\r\n]+'), ' ');
  return collapseSpaces(noBreaks).trim();
}

final _scriptish = RegExp(
  r'<\/|\/?script|javascript:|on\w+\s*=|<iframe|<object|<embed|<svg[\s\S]*on',
  caseSensitive: false,
);

bool containsHtmlOrScript(String value) {
  if (value.isEmpty) return false;
  if (_scriptish.hasMatch(value)) return true;
  if (RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(value)) {
    return true;
  }
  return false;
}

const _urlPattern =
    r'(?:https?:\/\/|www\.)[^\s]+|[a-z0-9][a-z0-9-]*\.[a-z]{2,}\b[^\s]*';

bool containsUrl(String value) {
  if (value.isEmpty) return false;
  return RegExp(_urlPattern, caseSensitive: false).hasMatch(value);
}

int countUrls(String value) {
  if (value.isEmpty) return 0;
  final m = RegExp(_urlPattern, caseSensitive: false).allMatches(value);
  return m.length;
}

/// Uses unicode extended pictographic class when supported by the VM.
final _emojiRe = RegExp(r'\p{Extended_Pictographic}', unicode: true);

int countEmojis(String value) {
  if (value.isEmpty) return 0;
  return _emojiRe.allMatches(value).length;
}

bool isOnlyNumbers(String value) {
  final t = trimText(value);
  if (t.isEmpty) return false;
  return RegExp(r'^[0-9０-９]+$').hasMatch(t);
}

bool isOnlySymbols(String value) {
  final t = trimText(value);
  if (t.isEmpty) return false;
  if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t)) return false;
  return RegExp(r'^[\p{S}\p{P}\s]+$', unicode: true).hasMatch(t);
}

bool hasExcessiveRepeatedCharacters(String value, [int maxRepeat = 4]) {
  if (value.isEmpty || maxRepeat < 2) return false;
  final re = RegExp('(.)\\1{$maxRepeat,}', unicode: true);
  return re.hasMatch(value);
}

int countLines(String value) {
  if (trimText(value).isEmpty) return 0;
  return value.split(RegExp(r'\r\n|\r|\n')).length;
}

int charLength(String value) => value.characters.length;

int countHashtags(String value) {
  if (value.isEmpty) return 0;
  final m = RegExp(r'#[\p{L}\p{N}_]+', unicode: true).allMatches(value);
  return m.length;
}
