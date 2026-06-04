import 'package:flutter/foundation.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/features/create/data/dto/draft_summary_completion.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Row-only draft summary for workspace lists (no sentences / learn blobs).
@immutable
class DraftListSummaryDto {
  const DraftListSummaryDto({
    required this.draftId,
    required this.title,
    this.coverImageUrl,
    required this.level,
    required this.category,
    required this.status,
    required this.publishState,
    this.processingStatus,
    this.updatedAt,
    required this.sentenceCount,
    required this.publishType,
    this.previewText,
    this.targetDurationBandKey,
    this.moduleWorkflowStatuses = const <String, String>{},
    this.learnModeEnabled = false,
    this.completionPercent,
    this.workspaceState,
    this.lastEditingStep,
    this.hasUnpublishedCoreChanges,
    this.contentLocale,
    this.learningLanguage,
  });

  final String draftId;
  final String title;
  final String? coverImageUrl;
  final String level;
  final String category;

  /// Coarse lifecycle (`draft`, `published`, …) — matches backend summary field.
  final String status;

  /// Same string keys as [StoryPublishState.storageKey].
  final String publishState;
  final String? processingStatus;
  final String? updatedAt;
  final int sentenceCount;

  /// `draft` | `read_only` | `full_learn` — backend display hint.
  final String publishType;
  final String? previewText;

  final String? targetDurationBandKey;

  /// Learn-module keys → status (`not_started` | `in_progress` | `completed`).
  final Map<String, String> moduleWorkflowStatuses;

  final bool learnModeEnabled;

  /// Server-derived 0–100, or locally computed in [fromCreatorStoryV1].
  final int? completionPercent;

  /// `draft` | `editing` — when null in JSON, derived from [publishState].
  final String? workspaceState;

  /// Module key heuristic when user left a learn module in progress.
  final String? lastEditingStep;

  /// When null on a published row, [effectiveDraftListWorkspaceState] treats as dirty.
  final bool? hasUnpublishedCoreChanges;

  /// Community / audience (`en` | `my` | `ja`); null = legacy.
  final String? contentLocale;

  /// Target learning language (V1: `ja`); null = legacy.
  final String? learningLanguage;

  /// Interim rows when the list endpoint returns **only** `draftId` (legacy / degraded server).
  factory DraftListSummaryDto.interimIdOnly(String draftId) {
    final id = draftId.trim();
    return DraftListSummaryDto(
      draftId: id,
      title: '',
      coverImageUrl: null,
      level: '',
      category: '',
      status: 'draft',
      publishState: StoryPublishState.draft.storageKey,
      processingStatus: null,
      updatedAt: null,
      sentenceCount: 0,
      publishType: 'draft',
      previewText: null,
      targetDurationBandKey: null,
      moduleWorkflowStatuses: const {},
      learnModeEnabled: false,
      completionPercent: null,
      workspaceState: 'draft',
      lastEditingStep: null,
      hasUnpublishedCoreChanges: false,
    );
  }

  factory DraftListSummaryDto.fromCreatorStoryV1(CreatorStoryV1 story) {
    final ps = story.publishState;
    final status = ps == StoryPublishState.draft ? 'draft' : 'published';
    final publishType = switch (ps) {
      StoryPublishState.draft => 'draft',
      StoryPublishState.readingOnlyPublished => 'read_only',
      StoryPublishState.fullLearnPublished => 'full_learn',
    };
    final desc = story.basics.description.trim();
    final modMap = mergeWithDefaultModuleStatuses({
      for (final id in LearnModuleId.values)
        id.storageKey: (story.moduleWorkflowStatuses[id] ??
                LearnModuleTaskStatus.notStarted)
            .storageKey,
    });
    final completion = computeCheapDraftSummaryCompletionPercent(
      title: story.basics.title,
      category: story.basics.category,
      level: story.basics.level,
      description: story.basics.description,
      targetDurationBandKey: story.basics.targetDurationBandKey,
      sentenceCount: story.sentences.length,
      moduleWorkflowStatuses: modMap,
    );
    final td = story.basics.targetDurationBandKey?.trim().isNotEmpty == true
        ? story.basics.targetDurationBandKey!.trim()
        : null;

    return DraftListSummaryDto(
      draftId: story.id.trim(),
      title: story.basics.title.trim(),
      coverImageUrl: story.basics.coverImageUrl,
      level: story.basics.level.trim().toLowerCase(),
      category: story.basics.category.trim().toLowerCase(),
      status: status,
      publishState: ps.storageKey,
      processingStatus: null,
      updatedAt: story.basics.updatedAt.toUtc().toIso8601String(),
      sentenceCount: story.sentences.length,
      publishType: publishType,
      previewText: _truncatePreview(desc),
      targetDurationBandKey: td,
      moduleWorkflowStatuses: modMap,
      learnModeEnabled: learnModeEnabledFromModuleMap(modMap),
      completionPercent: completion,
      workspaceState: ps == StoryPublishState.draft ? 'draft' : 'editing',
      lastEditingStep: lastEditingModuleHeuristic(modMap),
      hasUnpublishedCoreChanges: story.hasUnpublishedCoreChanges ??
          (ps == StoryPublishState.draft ? false : true),
      contentLocale: story.basics.contentLocale,
      learningLanguage: story.basics.learningLanguage,
    );
  }

  factory DraftListSummaryDto.fromJson(Map<String, Object?> m) {
    String s(Object? v) => v == null ? '' : v.toString().trim();

    final draftId = s(m['draftId']);
    final publishStateRaw = s(m['publishState']);
    final publishState = publishStateRaw.isEmpty
        ? StoryPublishState.draft.storageKey
        : publishStateRaw;

    final modMap = mergeWithDefaultModuleStatuses(
      _moduleMapFromJson(m['moduleWorkflowStatuses']),
    );
    final learnFromJson = _optBool(m['learnModeEnabled']);
    final learnMode = learnFromJson ?? learnModeEnabledFromModuleMap(modMap);

    final completionRaw = _optInt(m['completionPercent']);
    final int? completion = completionRaw == null
        ? null
        : completionRaw < 0
            ? 0
            : completionRaw > 100
                ? 100
                : completionRaw;

    final hucParsed = _optBool(m['hasUnpublishedCoreChanges']);
    final wsApi = _optWorkspaceStateThreeWay(m['workspaceState']);
    final String wsResolved;
    if (wsApi != null) {
      wsResolved = wsApi;
    } else if (publishState == StoryPublishState.draft.storageKey) {
      wsResolved = 'draft';
    } else {
      wsResolved = (hucParsed ?? true) ? 'editing' : 'synced';
    }

    final bool? hucForDto = publishState == StoryPublishState.draft.storageKey
        ? (hucParsed ?? false)
        : hucParsed;

    return DraftListSummaryDto(
      draftId: draftId,
      title: s(m['title']),
      coverImageUrl: _optStr(m['coverImageUrl']),
      level: s(m['level']).toLowerCase(),
      category: s(m['category']).toLowerCase(),
      status: s(m['status']).isEmpty ? 'draft' : s(m['status']),
      publishState: publishState,
      processingStatus: _optStr(m['processingStatus']),
      updatedAt: _optStr(m['updatedAt']),
      sentenceCount: _optInt(m['sentenceCount']) ?? 0,
      publishType: s(m['publishType']).isEmpty ? 'draft' : s(m['publishType']),
      previewText: _optStr(m['previewText']),
      targetDurationBandKey: _optStr(m['targetDurationBandKey']),
      moduleWorkflowStatuses: modMap,
      learnModeEnabled: learnMode,
      completionPercent: completion,
      workspaceState: wsResolved,
      lastEditingStep: _optStr(m['lastEditingStep']),
      hasUnpublishedCoreChanges: hucForDto,
      contentLocale: _optStr(m['contentLocale']),
      learningLanguage: _optStr(m['learningLanguage']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DraftListSummaryDto &&
        draftId == other.draftId &&
        title == other.title &&
        coverImageUrl == other.coverImageUrl &&
        level == other.level &&
        category == other.category &&
        status == other.status &&
        publishState == other.publishState &&
        processingStatus == other.processingStatus &&
        updatedAt == other.updatedAt &&
        sentenceCount == other.sentenceCount &&
        publishType == other.publishType &&
        previewText == other.previewText &&
        targetDurationBandKey == other.targetDurationBandKey &&
        mapEquals(moduleWorkflowStatuses, other.moduleWorkflowStatuses) &&
        learnModeEnabled == other.learnModeEnabled &&
        completionPercent == other.completionPercent &&
        workspaceState == other.workspaceState &&
        lastEditingStep == other.lastEditingStep &&
        hasUnpublishedCoreChanges == other.hasUnpublishedCoreChanges;
  }

  @override
  int get hashCode {
    final keys = moduleWorkflowStatuses.keys.toList()..sort();
    var mapH = 0;
    for (final k in keys) {
      mapH ^= Object.hash(k, moduleWorkflowStatuses[k]);
    }
    return Object.hash(
      draftId,
      title,
      coverImageUrl,
      level,
      category,
      status,
      publishState,
      processingStatus,
      updatedAt,
      sentenceCount,
      publishType,
      previewText,
      targetDurationBandKey,
      mapH,
      learnModeEnabled,
      completionPercent,
      workspaceState,
      lastEditingStep,
      hasUnpublishedCoreChanges,
    );
  }
}

/// Effective bucket for Workspace list + Published duplicate hide.
///
/// Published rows without [hasUnpublishedCoreChanges] are treated as **editing** (conservative).
String effectiveDraftListWorkspaceState(DraftListSummaryDto s) {
  final w = s.workspaceState?.trim().toLowerCase();
  if (w == 'draft' || w == 'editing' || w == 'synced') {
    return w!;
  }
  if (s.publishState == StoryPublishState.draft.storageKey) {
    return 'draft';
  }
  final dirty = s.hasUnpublishedCoreChanges ?? true;
  return dirty ? 'editing' : 'synced';
}

/// Parses GET /v1/story-drafts cursor envelope into [PageResult].
abstract final class DraftListPageDto {
  DraftListPageDto._();

  static PageResult<DraftListSummaryDto> parseEnvelope(
      Map<String, Object?> json) {
    final itemsRaw = (json['items'] as List?) ?? const [];
    final maps = <Map<String, Object?>>[
      for (final x in itemsRaw)
        if (x is Map) _asStringObjectMap(Map<dynamic, dynamic>.from(x)),
    ];

    final idOnly = maps.isNotEmpty && maps.every(_rowLooksIdOnly);

    if (idOnly) {
      return _parseInterimIdOnlyEnvelope(maps);
    }

    final items = <DraftListSummaryDto>[
      for (final m in maps) DraftListSummaryDto.fromJson(m),
    ];

    final nextCursor = _optStr(json['nextCursor']);
    final hasMore = _hasMoreFromJson(json);
    final totalCount = _totalCountFromJson(json);

    return PageResult<DraftListSummaryDto>(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: totalCount,
    );
  }

  /// Interim: server returned **only** `draftId` per row — cap rows and disable continuation.
  ///
  /// See `docs/WORKSPACE_DRAFT_PAGINATION_AUDIT.md` §6 (adapter-only / bounded path).
  static PageResult<DraftListSummaryDto> _parseInterimIdOnlyEnvelope(
    List<Map<String, Object?>> maps,
  ) {
    final cap = PaginationDefaults.workspacePageLimit;
    final n = maps.length < cap ? maps.length : cap;
    final out = <DraftListSummaryDto>[
      for (var i = 0; i < n; i++)
        DraftListSummaryDto.interimIdOnly(_draftIdOrEmpty(maps[i])),
    ];
    return PageResult<DraftListSummaryDto>(
      items: out,
      nextCursor: null,
      hasMore: false,
      totalCount: null,
    );
  }
}

Map<String, Object?> _asStringObjectMap(Map<dynamic, dynamic> m) {
  return m.map((k, v) => MapEntry(k.toString(), v as Object?));
}

String _draftIdOrEmpty(Map<String, Object?> m) {
  final v = m['draftId'];
  if (v == null) return '';
  return v.toString().trim();
}

bool _rowLooksIdOnly(Map<String, Object?> m) {
  final id = m['draftId']?.toString().trim();
  if (id == null || id.isEmpty) return false;
  // Any server-provided summary field → use [DraftListSummaryDto.fromJson] (tolerant).
  const summaryHints = {
    'title',
    'updatedAt',
    'publishState',
    'sentenceCount',
    'level',
    'category',
    'previewText',
    'coverImageUrl',
    'targetDurationBandKey',
    'moduleWorkflowStatuses',
    'learnModeEnabled',
    'completionPercent',
    'workspaceState',
    'lastEditingStep',
    'hasUnpublishedCoreChanges',
  };
  for (final k in summaryHints) {
    if (m.containsKey(k)) return false;
  }
  return true;
}

String? _optStr(Object? v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

int? _optInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool? _optBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true') return true;
  if (s == 'false') return false;
  return null;
}

String? _optWorkspaceStateThreeWay(Object? v) {
  final s = v?.toString().trim().toLowerCase() ?? '';
  if (s == 'draft' || s == 'editing' || s == 'synced') return s;
  return null;
}

Map<String, String> _moduleMapFromJson(Object? v) {
  if (v == null) return {};
  if (v is Map) {
    return v.map(
      (k, val) => MapEntry(k.toString(), val?.toString() ?? ''),
    );
  }
  return {};
}

bool _hasMoreFromJson(Map<String, Object?> m) {
  final v = m['hasMore'];
  if (v is bool) return v;
  final nc = m['nextCursor'];
  if (nc is String && nc.trim().isNotEmpty) return true;
  return false;
}

int? _totalCountFromJson(Map<String, Object?> m) {
  final v = m['totalCount'];
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String _truncatePreview(String text) {
  const max = 200;
  final t = text.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}
