import 'package:nimon/features/mono/mono_content_model.dart';

/// Lightweight V1 draft/publish payload for Mono (line-based).
class MonoDraftV1 {
  const MonoDraftV1({
    required this.id,
    required this.title,
    required this.jlptLevel,
    required this.content,
    required this.legacyBodyText,
    required this.updatedAt,
    this.published = false,
  });

  final String id;
  final String title;
  final String jlptLevel; // N5..N1
  final MonoContent content;

  /// Compatibility fallback used by legacy readers/export/share.
  final String legacyBodyText;

  final DateTime updatedAt;
  final bool published;

  MonoDraftV1 copyWith({
    String? title,
    String? jlptLevel,
    MonoContent? content,
    String? legacyBodyText,
    DateTime? updatedAt,
    bool? published,
  }) {
    return MonoDraftV1(
      id: id,
      title: title ?? this.title,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      content: content ?? this.content,
      legacyBodyText: legacyBodyText ?? this.legacyBodyText,
      updatedAt: updatedAt ?? this.updatedAt,
      published: published ?? this.published,
    );
  }

  /// Backward compatibility: create a draft from legacy raw body text.
  /// Splits by line breaks and produces `MonoSentenceLine(tokens: [], plainText: ...)`.
  factory MonoDraftV1.fromLegacyBody({
    required String id,
    required String title,
    required String jlptLevel,
    required String legacyBodyText,
    DateTime? updatedAt,
  }) {
    final lines = legacyBodyText
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(
          (t) => MonoSentenceLine(
            tokens: const [],
            plainText: t,
            explanation: null,
          ),
        )
        .toList(growable: false);
    final content = MonoContent(
      id: id,
      title: title,
      pages: [MonoContentPage(pageId: 'p1', lines: lines)],
    );
    return MonoDraftV1(
      id: id,
      title: title,
      jlptLevel: jlptLevel,
      content: content,
      legacyBodyText: legacyBodyText,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

