import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/remote_story_draft_learn_layers_wire.dart';
import 'package:nimon/features/create/data/remote_story_draft_sentence_wire.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/core/validation/quota_exceeded_from_json.dart';
import 'package:nimon/core/validation/validation_issue_from_json.dart';
import 'package:nimon/features/create/data/story_draft_remote_publish_errors.dart';
import 'package:nimon/features/create/data/story_draft_mapper.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';
import 'package:nimon/features/auth/authenticated_http.dart';
import 'package:nimon/features/create/data/published_edit_staging_guard.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorDraftResumeMeta, CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds `Authorization: Bearer …` for guarded Nest routes (M1b+).
typedef StoryDraftAuthHeaderBuilder = Future<Map<String, String>> Function();

/// Optional UI hook while a multi-step remote publish runs (nullable clears).
typedef StoryDraftPublishProgressCallback = void Function(String? message);

bool? _parseOptionalBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

class RemoteStoryDraftRepository implements StoryDraftRepository {
  RemoteStoryDraftRepository({
    required String apiBaseUrl,
    http.Client? client,
    StoryDraftRepository? fallbackLocal,
    StoryDraftAuthHeaderBuilder? authHeaderBuilder,
    NimonSendWithAuth401Recovery? sendWithAuth401Recovery,
    String Function()? resolveRemoteOwnerId,
    StoryDraftPublishProgressCallback? onPublishProgress,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'\/+$'), ''),
        _client = client ?? http.Client(),
        _local = fallbackLocal ?? const LocalStoryDraftRepository(),
        _authHeaderBuilder = authHeaderBuilder,
        _sendWithAuth401 = sendWithAuth401Recovery,
        _resolveRemoteOwnerId = resolveRemoteOwnerId,
        _onPublishProgress = onPublishProgress;

  final String _apiBaseUrl;
  final http.Client _client;
  final StoryDraftRepository _local;
  final StoryDraftAuthHeaderBuilder? _authHeaderBuilder;
  final NimonSendWithAuth401Recovery? _sendWithAuth401;
  final String Function()? _resolveRemoteOwnerId;
  final StoryDraftPublishProgressCallback? _onPublishProgress;

  Future<Map<String, String>> _mergeAuth(Map<String, String> headers) async {
    final builder = _authHeaderBuilder;
    if (builder == null) return headers;
    final auth = await builder();
    return {...auth, ...headers};
  }

  Future<http.Response> _nimonAuthSend(
    Uri uri,
    Future<Map<String, String>> Function() mergeHeaders,
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool skip401Recovery = false,
  }) =>
      nimonSendWithOptional401Recovery(
        _sendWithAuth401,
        requestUri: uri,
        mergeHeaders: mergeHeaders,
        send: send,
        skip401Recovery: skip401Recovery,
        requireAuthHeaderForRecovery: true,
      );

  /// When strict remote drafts are enabled, we must not mask backend errors by
  /// returning successful local fallback results.
  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

  void _m20eLogEditAction({
    required String tag,
    required String draftId,
    String? publishedMonoId,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[M20E $tag] draftId=$draftId publishedMonoId=${publishedMonoId ?? ''} '
      'apiBase=$_apiBaseUrl',
    );
  }

  void _m20eLogHttpResult(String op, http.Response r) {
    if (!kDebugMode) return;
    final code = _m20eBodyCodeKey(r.body);
    debugPrint(
      '[M20E edit-result] op=$op status=${r.statusCode} bodyCode=$code bodyKey=$code',
    );
  }

  String _m20eBodyCodeKey(String body) {
    final t = body.trim();
    if (t.isEmpty) return '';
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return '';
      final err = decoded['error'];
      if (err is Map) {
        final c = err['code'];
        if (c is String && c.isNotEmpty) return c;
      }
      final c = decoded['code'];
      if (c is String && c.isNotEmpty) return c;
    } catch (_) {
      return '';
    }
    return '';
  }

  Never _failRemotePublishIncomplete(String draftId, String step) {
    throw StoryDraftHttpResponseException(
      'Publish did not complete ($step). Try again from Review.',
    );
  }

  void _assertRemotePublishClean(StoryDraftDto dto, String draftId) {
    if (dto.hasUnpublishedCoreChanges == true) {
      throw StoryDraftHttpResponseException(
        'Publish did not complete: story still has unpublished changes.',
      );
    }
    final pm = dto.publishedMonoId?.trim() ?? '';
    if (pm.isEmpty) {
      _failRemotePublishIncomplete(draftId, 'missing publishedMonoId');
    }
  }

  T _fallbackOrThrow<T>(Object error, StackTrace st, T Function() fallback) {
    if (_strict) {
      Error.throwWithStackTrace(error, st);
    }
    return fallback();
  }

  Future<T> _fallbackOrThrowAsync<T>(
    Object error,
    StackTrace st,
    Future<T> Function() fallback,
  ) {
    if (_strict) {
      return Future.error(error, st);
    }
    return fallback();
  }

  static const _etagKeyPrefix = 'nimon_remote_draft_etag_v1_';
  static String _etagKey(String draftId) => '$_etagKeyPrefix${draftId.trim()}';

  Future<void> _saveEtag(String draftId, String? etag) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    if (etag == null || etag.trim().isEmpty) {
      await p.remove(_etagKey(id));
      return;
    }
    await p.setString(_etagKey(id), etag.trim());
  }

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, Object?>> _jsonObjectFromResponse(http.Response r) async {
    final body = r.body.trim();
    if (body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
    throw StateError('Expected JSON object response');
  }

  Future<void> _throwIfNotOk(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 401) notifyIfStrictUnauthorized401(r);
    final quota = tryParseQuotaExceededFromHttpBody(r.body);
    if (quota != null) throw quota;
    if (r.statusCode == 400) {
      final issues = tryParseValidationIssuesFromHttpBody(r.body);
      if (issues != null) {
        throw StoryDraftValidationFailedException(issues);
      }
    }
    final friendly = publishedMonoMissingFriendlyMessageIfAny(
      statusCode: r.statusCode,
      body: r.body,
    );
    if (friendly != null) {
      throw StoryDraftHttpResponseException(friendly);
    }
    // Bubble server envelope; UI shows [Exception.toString] via creator save errors.
    final msg = r.body.trim().isEmpty
        ? 'HTTP ${r.statusCode}'
        : 'HTTP ${r.statusCode}: ${r.body}';
    throw StoryDraftHttpResponseException(msg);
  }

  /// True when the backend reports `draft_not_found` (or an empty 404 body on draft routes).
  bool _isMissingDraftResponse(http.Response r) {
    if (r.statusCode != 404) return false;
    final body = r.body.trim();
    if (body.isEmpty) return true;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final err = decoded['error'];
      if (err is Map && err['code'] == 'draft_not_found') return true;
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Parses [error.details.currentEtag] from a Nest `409` `conflict` draft response.
  String? _parseConflictCurrentEtag(http.Response r) {
    if (r.statusCode != 409) return null;
    final body = r.body.trim();
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final err = decoded['error'];
      if (err is! Map) return null;
      if (err['code'] != 'conflict') return null;
      final details = err['details'];
      if (details is! Map) return null;
      final tag = details['currentEtag'];
      if (tag is String && tag.trim().isNotEmpty) return tag.trim();
    } catch (_) {
      return null;
    }
    return null;
  }

  /// One automatic retry on stale If-Match: updates stored etag, re-sends same [body] intent.
  Future<http.Response> _retryOnceOn409Conflict({
    required String draftId,
    required String operation,
    required http.Response firstResp,
    required String firstIfMatch,
    required Future<http.Response> Function(String ifMatch) sendWithIfMatch,
  }) async {
    final current = _parseConflictCurrentEtag(firstResp);
    if (current == null || current.isEmpty) {
      return firstResp;
    }
    developer.log(
      'draftId=$draftId op=$operation HTTP 409 conflict oldIfMatch="$firstIfMatch" '
      'currentEtagFromServer="$current" retryCount=1',
      name: 'RemoteStoryDraftRepository',
    );
    await _saveEtag(draftId, current);
    final second = await sendWithIfMatch(current);
    developer.log(
      'draftId=$draftId op=$operation after409Retry httpStatus=${second.statusCode}',
      name: 'RemoteStoryDraftRepository',
    );
    return second;
  }

  static bool _publishedMonoIdMissing(StoryDraftDto dto) {
    final v = dto.publishedMonoId?.trim() ?? '';
    return v.isEmpty;
  }

  Future<StoryDraftDto> _postPublishReadOnlyHttp(
    String draftId,
    String ifMatch, {
    String? publishedMonoIdHint,
  }) async {
    final id = draftId.trim();
    _m20eLogEditAction(
      tag: 'edit-update',
      draftId: id,
      publishedMonoId: publishedMonoIdHint,
    );
    if (kDebugMode) {
      debugPrint(
        '[M20E update-url] ${_u('/v1/story-drafts/$id/publish/read-only')}',
      );
    }
    var sent = ifMatch.trim();
    http.Response roResp = await _nimonAuthSend(
      _u('/v1/story-drafts/$id/publish/read-only'),
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'If-Match': sent,
      }),
      (h) => _client.post(
        _u('/v1/story-drafts/$id/publish/read-only'),
        headers: h,
        body: jsonEncode({}),
      ),
    );
    roResp = await _retryOnceOn409Conflict(
      draftId: id,
      operation: 'POST publish/read-only',
      firstResp: roResp,
      firstIfMatch: sent,
      sendWithIfMatch: (match) async => _nimonAuthSend(
        _u('/v1/story-drafts/$id/publish/read-only'),
        () => _mergeAuth({
          'Content-Type': 'application/json',
          'If-Match': match,
        }),
        (h) => _client.post(
          _u('/v1/story-drafts/$id/publish/read-only'),
          headers: h,
          body: jsonEncode({}),
        ),
      ),
    );
    await _throwIfNotOk(roResp);
    _m20eLogHttpResult('publish/read-only', roResp);
    developer.log(
      'draftId=$id publish read-only succeeded httpStatus=${roResp.statusCode}',
      name: 'RemoteStoryDraftRepository',
    );
    final dto = _dtoFromJson(await _jsonObjectFromResponse(roResp));
    _assertRemotePublishClean(dto, id);
    return dto;
  }

  Future<StoryDraftDto> _postPublishFullLearnHttp(
    String draftId,
    String ifMatch, {
    String? publishedMonoIdHint,
  }) async {
    final id = draftId.trim();
    _m20eLogEditAction(
      tag: 'edit-update',
      draftId: id,
      publishedMonoId: publishedMonoIdHint,
    );
    if (kDebugMode) {
      debugPrint(
        '[M20E update-url] ${_u('/v1/story-drafts/$id/publish/full-learn')}',
      );
    }
    var sent = ifMatch.trim();
    http.Response flResp = await _nimonAuthSend(
      _u('/v1/story-drafts/$id/publish/full-learn'),
      () => _mergeAuth({
        'Content-Type': 'application/json',
        'If-Match': sent,
      }),
      (h) => _client.post(
        _u('/v1/story-drafts/$id/publish/full-learn'),
        headers: h,
        body: jsonEncode({}),
      ),
    );
    flResp = await _retryOnceOn409Conflict(
      draftId: id,
      operation: 'POST publish/full-learn',
      firstResp: flResp,
      firstIfMatch: sent,
      sendWithIfMatch: (match) async => _nimonAuthSend(
        _u('/v1/story-drafts/$id/publish/full-learn'),
        () => _mergeAuth({
          'Content-Type': 'application/json',
          'If-Match': match,
        }),
        (h) => _client.post(
          _u('/v1/story-drafts/$id/publish/full-learn'),
          headers: h,
          body: jsonEncode({}),
        ),
      ),
    );
    await _throwIfNotOk(flResp);
    _m20eLogHttpResult('publish/full-learn', flResp);
    developer.log(
      'draftId=$id publish full-learn succeeded httpStatus=${flResp.statusCode}',
      name: 'RemoteStoryDraftRepository',
    );
    final dto = _dtoFromJson(await _jsonObjectFromResponse(flResp));
    _assertRemotePublishClean(dto, id);
    return dto;
  }

  StoryDraftDto _dtoFromJson(Map<String, Object?> m) {
    // Minimal, tolerant parse (contract parity). Only reads what mapper needs.
    final basicsRaw =
        (m['basics'] as Map?)?.cast<String, Object?>() ?? const {};
    final sentencesRaw = (m['sentences'] as List?) ?? const [];
    final vocabRaw =
        (m['vocabularyKanji'] as Map?)?.cast<String, Object?>() ?? const {};
    final grammarRaw =
        (m['grammar'] as Map?)?.cast<String, Object?>() ?? const {};
    final quizRaw = (m['quiz'] as Map?)?.cast<String, Object?>() ?? const {};
    final audioRaw = (m['audio'] as Map?)?.cast<String, Object?>() ?? const {};

    return StoryDraftDto(
      draftId: (m['draftId'] as String?) ?? '',
      schemaVersion: (m['schemaVersion'] as int?) ?? 1,
      ownerId: m['ownerId'] as String?,
      createdAt: m['createdAt'] as String?,
      updatedAt: m['updatedAt'] as String?,
      publishedMonoId: m['publishedMonoId'] as String?,
      readingOnlyPublishedAt: m['readingOnlyPublishedAt'] as String?,
      fullLearnPublishedAt: m['fullLearnPublishedAt'] as String?,
      hasUnpublishedCoreChanges:
          _parseOptionalBool(m['hasUnpublishedCoreChanges']),
      etag: m['etag'] as String?,
      basics: StoryDraftBasicsDto(
        storyId: (basicsRaw['storyId'] as String?) ??
            ((m['draftId'] as String?) ?? ''),
        ownerId: (basicsRaw['ownerId'] as String?) ??
            ((m['ownerId'] as String?) ?? ''),
        title: (basicsRaw['title'] as String?) ?? '',
        category: (basicsRaw['category'] as String?) ?? '',
        level: (basicsRaw['level'] as String?) ?? '',
        description: (basicsRaw['description'] as String?) ?? '',
        promptSourceNote: (basicsRaw['promptSourceNote'] as String?) ?? '',
        targetDurationBandKey: basicsRaw['targetDurationBandKey'] as String?,
        coverImageUrl: basicsRaw['coverImageUrl'] as String?,
        createdAt: (basicsRaw['createdAt'] as String?) ??
            ((m['createdAt'] as String?) ?? ''),
        updatedAt: (basicsRaw['updatedAt'] as String?) ??
            ((m['updatedAt'] as String?) ?? ''),
      ),
      sentences: [
        for (final x in sentencesRaw)
          _sentenceDtoFromJson((x as Map).cast<String, Object?>()),
      ],
      vocabularyKanji: VocabularyKanjiLayerDto(
        entries: [
          for (final x in ((vocabRaw['entries'] as List?) ?? const []))
            _vocabDtoFromJson((x as Map).cast<String, Object?>()),
        ],
      ),
      grammar: GrammarLayerDto(
        entries: [
          for (final x in ((grammarRaw['entries'] as List?) ?? const []))
            _grammarDtoFromJson((x as Map).cast<String, Object?>()),
        ],
      ),
      quiz: QuizLayerDto(
        entries: [
          for (final x in ((quizRaw['entries'] as List?) ?? const []))
            _quizDtoFromJson((x as Map).cast<String, Object?>()),
        ],
      ),
      audio: AudioLayerDto(
        storyAudio:
            (audioRaw['storyAudio'] as Map?)?.cast<String, Object?>() == null
                ? null
                : _audioDtoFromJson(
                    (audioRaw['storyAudio'] as Map).cast<String, Object?>()),
      ),
      publishState: (m['publishState'] as String?) ?? 'draft',
      moduleWorkflowStatuses:
          (m['moduleWorkflowStatuses'] as Map?)?.cast<String, String>() ??
              const {},
    );
  }

  // ---- DTO JSON helpers (minimal, only what's needed for the mapper) ----

  StorySentenceDto _sentenceDtoFromJson(Map<String, Object?> m) {
    return storySentenceDtoFromWireJson(m);
  }

  VocabularyKanjiEntryDto _vocabDtoFromJson(Map<String, Object?> m) {
    return vocabularyKanjiEntryDtoFromWireJson(m);
  }

  GrammarEntryDto _grammarDtoFromJson(Map<String, Object?> m) {
    return grammarEntryDtoFromWireJson(m);
  }

  QuizEntryDto _quizDtoFromJson(Map<String, Object?> m) {
    return quizEntryDtoFromWireJson(m);
  }

  StoryAudioDto _audioDtoFromJson(Map<String, Object?> m) {
    return storyAudioDtoFromWireJson(m);
  }

  Map<String, Object?> _dtoToJsonMap(StoryDraftDto dto) {
    return {
      'schemaVersion': dto.schemaVersion,
      'basics': _basicsToJson(dto.basics),
      // Backend uses array order as canonical sentence order; align orderIndex with index.
      'sentences': [
        for (var i = 0; i < dto.sentences.length; i++)
          _sentenceToJson(
            StorySentenceDto(
              id: dto.sentences[i].id,
              storyId: dto.sentences[i].storyId,
              orderIndex: i,
              japaneseText: dto.sentences[i].japaneseText,
              reading: dto.sentences[i].reading,
              furiganaSpans: dto.sentences[i].furiganaSpans,
              meanings: dto.sentences[i].meanings,
              audioStartMs: dto.sentences[i].audioStartMs,
              audioEndMs: dto.sentences[i].audioEndMs,
              provenance: dto.sentences[i].provenance,
            ),
          ),
      ],
      'vocabularyKanji': {
        'entries': [
          for (final e in dto.vocabularyKanji.entries) _vocabToJson(e)
        ],
      },
      'grammar': {
        'entries': [for (final e in dto.grammar.entries) _grammarToJson(e)],
      },
      'quiz': {
        'entries': [for (final e in dto.quiz.entries) _quizToJson(e)],
      },
      'audio': {
        'storyAudio': dto.audio.storyAudio == null
            ? null
            : _audioToJson(dto.audio.storyAudio!),
      },
      'publishState': dto.publishState,
      'moduleWorkflowStatuses': dto.moduleWorkflowStatuses,
    };
  }

  Map<String, Object?> _basicsToJson(StoryDraftBasicsDto b) => {
        'storyId': b.storyId,
        'ownerId': b.ownerId,
        'title': b.title,
        'category': b.category,
        'level': b.level,
        'description': b.description,
        'promptSourceNote': b.promptSourceNote,
        'targetDurationBandKey': b.targetDurationBandKey,
        'coverImageUrl': b.coverImageUrl,
        'createdAt': b.createdAt,
        'updatedAt': b.updatedAt,
      };

  Map<String, Object?> _sentenceToJson(StorySentenceDto s) =>
      storySentenceDtoToWireJson(s);

  Map<String, Object?> _vocabToJson(VocabularyKanjiEntryDto e) =>
      vocabularyKanjiEntryDtoToWireJson(e);

  Map<String, Object?> _grammarToJson(GrammarEntryDto e) =>
      grammarEntryDtoToWireJson(e);

  Map<String, Object?> _quizToJson(QuizEntryDto e) => quizEntryDtoToWireJson(e);

  Map<String, Object?> _audioToJson(StoryAudioDto a) =>
      storyAudioDtoToWireJson(a);

  // ---------------------------------------------------------------------------
  // StoryDraftRepository implementation
  // ---------------------------------------------------------------------------

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async {
    try {
      final resp = await _nimonAuthSend(
        _u('/v1/story-drafts'),
        () => _mergeAuth({'Content-Type': 'application/json'}),
        (h) => _client.post(
          _u('/v1/story-drafts'),
          headers: h,
          body: jsonEncode({'schemaVersion': 1}),
        ),
      );
      await _throwIfNotOk(resp);
      final m = await _jsonObjectFromResponse(resp);
      final dto = _dtoFromJson(m);
      await _saveEtag(dto.draftId, dto.etag);
      final domain = StoryDraftMapper.toDomain(dto);
      // Keep local copy for fallback / offline resume.
      return await _local.saveDraft(domain);
    } catch (e, st) {
      return await _fallbackOrThrowAsync(
        e,
        st,
        () => _local.createNewDraft(ownerId: ownerId),
      );
    }
  }

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return null;
    try {
      final resp = await _nimonAuthSend(
        _u('/v1/story-drafts/$id'),
        () => _mergeAuth({}),
        (h) => _client.get(_u('/v1/story-drafts/$id'), headers: h),
      );
      await _throwIfNotOk(resp);
      final m = await _jsonObjectFromResponse(resp);
      final dto = _dtoFromJson(m);
      await _saveEtag(id, dto.etag);
      final domain = StoryDraftMapper.toDomain(dto);
      await _local.saveDraft(domain);
      return domain;
    } catch (e, st) {
      return await _fallbackOrThrowAsync(e, st, () => _local.loadDraft(id));
    }
  }

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() async {
    // V1 remote list is lightweight; use ids + loadDraft (best-effort).
    final ids = await listDraftIds();
    final out = <CreatorStoryV1>[];
    for (final id in ids) {
      final d = await loadDraft(id);
      if (d != null) out.add(d);
    }
    return out;
  }

  @override
  Future<List<String>> listDraftIds() async {
    try {
      final resp = await _nimonAuthSend(
        _u('/v1/story-drafts'),
        () => _mergeAuth({}),
        (h) => _client.get(_u('/v1/story-drafts'), headers: h),
      );
      await _throwIfNotOk(resp);
      final m = await _jsonObjectFromResponse(resp);
      final items = (m['items'] as List?) ?? const [];
      final ids = <String>[
        for (final x in items)
          if (x is Map && x['draftId'] is String)
            (x['draftId'] as String).trim(),
      ]..removeWhere((x) => x.isEmpty);
      return ids;
    } catch (e, st) {
      return await _fallbackOrThrowAsync(e, st, () => _local.listDraftIds());
    }
  }

  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async {
    try {
      final uri = _u('/v1/story-drafts').replace(
        queryParameters: request.toQueryParameters(),
      );
      final resp = await _nimonAuthSend(
        uri,
        () => _mergeAuth({}),
        (h) => _client.get(uri, headers: h),
      );
      await _throwIfNotOk(resp);
      final m = await _jsonObjectFromResponse(resp);
      return DraftListPageDto.parseEnvelope(m);
    } catch (e, st) {
      return await _fallbackOrThrowAsync(
        e,
        st,
        () => _local.fetchWorkspaceDraftPage(request),
      );
    }
  }

  /// GET draft from backend only (no local fallback). Returns null when the row does not exist.
  Future<String?> _tryFetchRemoteEtag(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return null;
    final resp = await _nimonAuthSend(
      _u('/v1/story-drafts/$id'),
      () => _mergeAuth({}),
      (h) => _client.get(_u('/v1/story-drafts/$id'), headers: h),
    );
    if (_isMissingDraftResponse(resp)) {
      return null;
    }
    await _throwIfNotOk(resp);
    final dto = _dtoFromJson(await _jsonObjectFromResponse(resp));
    final etag = dto.etag?.trim();
    if (etag == null || etag.isEmpty) {
      throw StateError(
          'RemoteStoryDraftRepository: GET /v1/story-drafts/$id missing etag');
    }
    await _saveEtag(id, etag);
    return etag;
  }

  /// POST /v1/story-drafts with [draftId] so a local-only draft can be migrated to the backend shell.
  Future<StoryDraftDto> _postCreateRemoteShellForMigration(
    String draftId,
    StoryDraftDto dto,
  ) async {
    final id = draftId.trim();
    final b = dto.basics;
    final body = <String, Object?>{
      'schemaVersion': 1,
      'draftId': id,
      'basics': <String, Object?>{
        'title': b.title,
        'category': b.category,
        'level': b.level,
        'description': b.description,
        'promptSourceNote': b.promptSourceNote,
        'targetDurationBandKey': b.targetDurationBandKey,
        'coverImageUrl': b.coverImageUrl,
      },
    };
    final resp = await _nimonAuthSend(
      _u('/v1/story-drafts'),
      () => _mergeAuth({'Content-Type': 'application/json'}),
      (h) => _client.post(
        _u('/v1/story-drafts'),
        headers: h,
        body: jsonEncode(body),
      ),
    );
    await _throwIfNotOk(resp);
    final created = _dtoFromJson(await _jsonObjectFromResponse(resp));
    final etag = created.etag?.trim();
    if (etag == null || etag.isEmpty) {
      throw StateError(
        'RemoteStoryDraftRepository: POST /v1/story-drafts did not return etag for $id',
      );
    }
    await _saveEtag(id, etag);
    return created;
  }

  /// Ensures a remote row exists and returns a valid If-Match value for PUT (refreshes from GET first).
  Future<String> _resolveRemoteEtagForSave(
      String draftId, StoryDraftDto dto) async {
    final id = draftId.trim();
    var etag = await _tryFetchRemoteEtag(id);
    if (etag != null && etag.isNotEmpty) {
      return etag;
    }
    developer.log(
      'Remote draft row missing for $id; POST /v1/story-drafts with client draftId to migrate '
      'local-only draft before PUT',
      name: 'RemoteStoryDraftRepository',
    );
    final created = await _postCreateRemoteShellForMigration(id, dto);
    final out = created.etag?.trim();
    if (out == null || out.isEmpty) {
      throw StateError(
          'RemoteStoryDraftRepository: migration create missing etag for $id');
    }
    return out;
  }

  /// Aligns [StoryBasics.creatorOwnerId] with the JWT user id (or dev fallback UUID).
  CreatorStoryV1 _normalizeDevOwnerForRemoteSave(CreatorStoryV1 story) {
    final fn = _resolveRemoteOwnerId;
    final fromResolver = fn != null ? fn().trim() : '';
    final expected = fromResolver.isNotEmpty
        ? fromResolver
        : RemoteBackendConfig.devOwnerId.trim();
    final cur = story.basics.creatorOwnerId.trim();
    if (cur == expected) return story;
    developer.log(
      'remote owner normalize draftId=${story.id.trim()} was="$cur" now="$expected"',
      name: 'RemoteStoryDraftRepository',
    );
    return story.copyWith(
      basics: story.basics.copyWith(creatorOwnerId: expected),
    );
  }

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async {
    // Keep local persist semantics intact (updatedAt bump).
    final locallySaved = await _local.saveDraft(draft);

    // Remote sync: if it fails, local remains the source of truth for now.
    var persisted = locallySaved;
    try {
      final normalizedForRemote = _normalizeDevOwnerForRemoteSave(locallySaved);
      if (normalizedForRemote.basics.creatorOwnerId.trim() !=
          locallySaved.basics.creatorOwnerId.trim()) {
        persisted = await _local.saveDraft(normalizedForRemote);
      }

      final id = persisted.id.trim();
      if (id.isEmpty) return persisted;

      // Always send remote-safe payload.
      final dto = StoryDraftMapper.fromDomainRemoteSafe(persisted);
      developer.log(
        'saveDraft remote draftId=$id outgoing dto.basics.ownerId="${dto.basics.ownerId}" '
        'remotePublishAfterPut=$remotePublishAfterPut '
        'RemoteBackendConfig.devOwnerId="${RemoteBackendConfig.devOwnerId}"',
        name: 'RemoteStoryDraftRepository',
      );

      // Resolve If-Match from GET (authoritative; avoids stale SharedPreferences etags).
      // If the backend has no row yet (local-only draft), POST create with client draftId, then PUT.
      final etag = await _resolveRemoteEtagForSave(id, dto);

      /// PUT updates StoryDraft only; [remotePublishAfterPut] triggers explicit publish POSTs.
      final putPayload = _dtoToJsonMap(dto);

      var sentIfMatch = etag.trim();
      http.Response putResp = await _nimonAuthSend(
        _u('/v1/story-drafts/$id'),
        () => _mergeAuth({
          'Content-Type': 'application/json',
          'If-Match': sentIfMatch,
        }),
        (h) => _client.put(
          _u('/v1/story-drafts/$id'),
          headers: h,
          body: jsonEncode(putPayload),
        ),
      );
      if (_isMissingDraftResponse(putResp)) {
        developer.log(
          'RemoteStoryDraftRepository: PUT draft_not_found for $id after etag resolve; '
          'migrating with POST then retrying PUT once',
          name: 'RemoteStoryDraftRepository',
        );
        await _saveEtag(id, null);
        final recreated = await _postCreateRemoteShellForMigration(id, dto);
        final retryEtag = recreated.etag?.trim();
        if (retryEtag == null || retryEtag.isEmpty) {
          throw StateError(
            'RemoteStoryDraftRepository: migration retry missing etag for $id',
          );
        }
        sentIfMatch = retryEtag;
        putResp = await _nimonAuthSend(
          _u('/v1/story-drafts/$id'),
          () => _mergeAuth({
            'Content-Type': 'application/json',
            'If-Match': sentIfMatch,
          }),
          (h) => _client.put(
            _u('/v1/story-drafts/$id'),
            headers: h,
            body: jsonEncode(putPayload),
          ),
        );
      }

      // Stale If-Match (e.g. overlapping autosaves): apply server currentEtag, retry same local payload once.
      putResp = await _retryOnceOn409Conflict(
        draftId: id,
        operation: 'PUT draft content',
        firstResp: putResp,
        firstIfMatch: sentIfMatch,
        sendWithIfMatch: (match) async => _nimonAuthSend(
          _u('/v1/story-drafts/$id'),
          () => _mergeAuth({
            'Content-Type': 'application/json',
            'If-Match': match,
          }),
          (h) => _client.put(
            _u('/v1/story-drafts/$id'),
            headers: h,
            body: jsonEncode(putPayload),
          ),
        ),
      );

      await _throwIfNotOk(putResp);
      developer.log(
        'draftId=$id PUT content succeeded httpStatus=${putResp.statusCode}',
        name: 'RemoteStoryDraftRepository',
      );
      final putDto = _dtoFromJson(await _jsonObjectFromResponse(putResp));
      await _saveEtag(id, putDto.etag);
      if (kDebugMode) {
        debugPrint(
          '[remote_draft] PUT mapped draftId=$id '
          'hasUnpublishedCoreChanges=${putDto.hasUnpublishedCoreChanges}',
        );
      }

      if (remotePublishAfterPut == StoryDraftRemotePublishIntent.readOnly) {
        _m20eLogEditAction(
          tag: 'edit-update',
          draftId: id,
          publishedMonoId: putDto.publishedMonoId,
        );
        final roEtag = (putDto.etag != null && putDto.etag!.trim().isNotEmpty)
            ? putDto.etag!.trim()
            : await _tryFetchRemoteEtag(id);
        if (roEtag == null || roEtag.isEmpty) {
          _failRemotePublishIncomplete(
              id, 'missing If-Match before read-only publish');
        }
        final roDto = await _postPublishReadOnlyHttp(
          id,
          roEtag.trim(),
          publishedMonoIdHint: putDto.publishedMonoId,
        );
        await _saveEtag(id, roDto.etag);
        final domain = StoryDraftMapper.toDomain(roDto);
        return await _local.saveDraft(domain);
      }

      if (remotePublishAfterPut == StoryDraftRemotePublishIntent.fullLearn) {
        _m20eLogEditAction(
          tag: 'edit-update',
          draftId: id,
          publishedMonoId: putDto.publishedMonoId,
        );
        var workEtag = (putDto.etag != null && putDto.etag!.trim().isNotEmpty)
            ? putDto.etag!.trim()
            : await _tryFetchRemoteEtag(id);
        if (workEtag == null || workEtag.isEmpty) {
          _failRemotePublishIncomplete(
              id, 'missing If-Match before full-learn publish');
        }
        var serverDto = putDto;
        if (_publishedMonoIdMissing(serverDto)) {
          _onPublishProgress?.call('Publishing story…');
          serverDto = await _postPublishReadOnlyHttp(
            id,
            workEtag.trim(),
            publishedMonoIdHint: putDto.publishedMonoId,
          );
          await _saveEtag(id, serverDto.etag);
          final nextTag = serverDto.etag?.trim();
          if (nextTag == null || nextTag.isEmpty) {
            _failRemotePublishIncomplete(
              id,
              'missing If-Match after read-only before full-learn',
            );
          }
          workEtag = nextTag;
        }
        _onPublishProgress?.call('Publishing learn modules…');
        final flDto = await _postPublishFullLearnHttp(
          id,
          workEtag.trim(),
          publishedMonoIdHint:
              serverDto.publishedMonoId ?? putDto.publishedMonoId,
        );
        await _saveEtag(id, flDto.etag);
        _onPublishProgress?.call(null);
        final domain = StoryDraftMapper.toDomain(flDto);
        return await _local.saveDraft(domain);
      }

      // No publish: just return updated from PUT.
      final domain = StoryDraftMapper.toDomain(putDto);
      return await _local.saveDraft(domain);
    } catch (e, st) {
      _onPublishProgress?.call(null);
      if (remotePublishAfterPut != StoryDraftRemotePublishIntent.none) {
        Error.throwWithStackTrace(e, st);
      }
      // In strict mode, fail loudly even though we already persisted locally.
      // This prevents remote/backend issues from being masked during development.
      return _fallbackOrThrow(e, st, () => persisted);
    }
  }

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) => saveDraft(draft);

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {
    // Persist content (local-first; remote best-effort), then update local resume meta.
    final persisted = await saveDraftNow(draft);
    final id = persisted.id.trim();
    if (id.isNotEmpty) {
      await updateResumeMeta(
        id,
        lastActiveModule: lastActiveModule,
        lastActiveSubPage: lastActiveSubPage,
        touchEditedAtUtc: touchEditedAtUtc,
      );
    }
    return persisted;
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;

    try {
      final resp = await _nimonAuthSend(
        _u('/v1/story-drafts/$id'),
        () => _mergeAuth({}),
        (h) => _client.delete(_u('/v1/story-drafts/$id'), headers: h),
      );
      await _throwIfNotOk(resp);
      await _saveEtag(id, null);
      await _local.deleteDraft(id);
    } catch (e, st) {
      if (e is AppQuotaExceededException) {
        Error.throwWithStackTrace(e, st);
      }
      await _fallbackOrThrowAsync<void>(
        e,
        st,
        () async {
          await _saveEtag(id, null);
          await _local.deleteDraft(id);
        },
      );
    }
  }

  @override
  Future<bool> discardPublishedEditStaging(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return false;
    _m20eLogEditAction(tag: 'edit-cancel', draftId: id);
    if (kDebugMode) {
      debugPrint('[M20E cancel-url] ${_u('/v1/story-drafts/$id')}');
    }

    CreatorStoryV1? draft;
    try {
      final getResp = await _nimonAuthSend(
        _u('/v1/story-drafts/$id'),
        () => _mergeAuth(const {'Accept': 'application/json'}),
        (h) => _client.get(_u('/v1/story-drafts/$id'), headers: h),
      );
      if (_isMissingDraftResponse(getResp)) return false;
      _m20eLogHttpResult('discard/get', getResp);
      await _throwIfNotOk(getResp);
      final dto = _dtoFromJson(await _jsonObjectFromResponse(getResp));
      draft = StoryDraftMapper.toDomain(dto);
      _m20eLogEditAction(
        tag: 'edit-cancel',
        draftId: id,
        publishedMonoId: draft.publishedMonoId,
      );
    } catch (e, st) {
      if (e is AppQuotaExceededException) rethrow;
      if (_strict) Error.throwWithStackTrace(e, st);
      return false;
    }

    if (!isLinkedPublishedEditStagingDraft(draft)) return false;

    try {
      final delResp = await _nimonAuthSend(
        _u('/v1/story-drafts/$id'),
        () => _mergeAuth({}),
        (h) => _client.delete(_u('/v1/story-drafts/$id'), headers: h),
      );
      _m20eLogHttpResult('discard/delete', delResp);
      await _throwIfNotOk(delResp);
      await _saveEtag(id, null);
      try {
        await _local.deleteDraft(id);
      } catch (_) {
        // Best-effort local cache cleanup.
      }
      return true;
    } on AppQuotaExceededException {
      rethrow;
    } catch (e, st) {
      if (_strict) Error.throwWithStackTrace(e, st);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Local-only / resume-meta methods: delegate to local repository
  // ---------------------------------------------------------------------------

  @override
  Future<void> clearActiveDraft() => _local.clearActiveDraft();

  @override
  Future<DateTime?> savedAt(String draftId) => _local.savedAt(draftId);

  @override
  Future<bool> hasAnyIndexedDraft() => _local.hasAnyIndexedDraft();

  @override
  Future<DateTime?> savedAtActiveDraft() => _local.savedAtActiveDraft();

  @override
  Future<bool> hasDraft(String draftId) => _local.hasDraft(draftId);

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) =>
      _local.loadResumeMeta(draftId);

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) =>
      _local.ensureResumeMetaInitialized(draftId);

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) =>
      _local.recordResumeNavigation(
          draftId: draftId, module: module, subPage: subPage);

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) =>
      _local.saveResumeMeta(meta);

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      _local.updateResumeMeta(
        draftId,
        lastActiveModule: lastActiveModule,
        lastActiveSubPage: lastActiveSubPage,
        touchEditedAtUtc: touchEditedAtUtc,
      );

  @override
  Future<void> clearResumeMeta(String draftId) =>
      _local.clearResumeMeta(draftId);
}
