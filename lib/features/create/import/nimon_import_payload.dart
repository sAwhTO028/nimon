import 'package:nimon/features/create/import/nimon_import_meta.dart';

// -----------------------------------------------------------------------------
// High-level wrapper for parsed AI JSON (untrusted).
//
// Holds opaque section maps until a future validator + mapper run.
// Do not deserialize [rawJson] into [CreatorStoryV1].
// -----------------------------------------------------------------------------

/// Parsed AI import file at the contract boundary (pre-validation).
class NimonImportRawPayload {
  const NimonImportRawPayload({
    required this.rawJson,
    this.meta,
    this.core,
    this.learn,
    this.publishKindRaw,
    this.sourceDraftId,
  });

  /// Full parsed root object (unmodified).
  final Map<String, dynamic> rawJson;

  /// Parsed `nimonImportMeta` when present.
  final NimonImportMeta? meta;

  /// Story core subtree when present (`core` or legacy top-level basics/sentences).
  final Map<String, dynamic>? core;

  /// Full Learn subtree when present (`learn` or module buckets).
  final Map<String, dynamic>? learn;

  /// Raw publish kind string from meta or root (for error messages).
  final String? publishKindRaw;

  /// Optional upstream draft id from generator/export.
  final String? sourceDraftId;

  bool get hasMeta => meta != null;

  bool get hasCoreSection => core != null && core!.isNotEmpty;

  bool get hasLearnSection => learn != null && learn!.isNotEmpty;

  /// Best-effort parse from decoded JSON root. Structural checks only.
  factory NimonImportRawPayload.fromJsonMap(Map<String, Object?> json) {
    final raw = Map<String, dynamic>.from(json);

    NimonImportMeta? meta;
    final metaRaw = json['nimonImportMeta'];
    if (metaRaw is Map) {
      meta = NimonImportMeta.fromJsonMap(
        Map<String, Object?>.from(metaRaw.cast<String, Object?>()),
      );
    }

    final core = _optObjectMap(json['core']);
    final learn = _optObjectMap(json['learn']);

    final publishKindRoot = _optStr(json['publishKind']);
    final publishKindRaw = meta?.publishKindRaw ??
        (publishKindRoot.isEmpty ? null : publishKindRoot);

    final sourceDraftIdRaw = _optStr(json['sourceDraftId']);
    final sourceDraftId =
        sourceDraftIdRaw.isEmpty ? null : sourceDraftIdRaw;

    return NimonImportRawPayload(
      rawJson: raw,
      meta: meta,
      core: core,
      learn: learn,
      publishKindRaw: publishKindRaw,
      sourceDraftId: sourceDraftId,
    );
  }

  @override
  String toString() =>
      'NimonImportRawPayload(hasMeta=$hasMeta, hasCore=$hasCoreSection, '
      'hasLearn=$hasLearnSection, publishKindRaw=$publishKindRaw, '
      'sourceDraftId=$sourceDraftId)';
}

Map<String, dynamic>? _optObjectMap(Object? v) {
  if (v is! Map) return null;
  final out = <String, dynamic>{};
  for (final e in v.entries) {
    out[e.key.toString()] = e.value;
  }
  return out.isEmpty ? null : out;
}

String _optStr(Object? v) {
  if (v == null) return '';
  return v.toString().trim();
}
