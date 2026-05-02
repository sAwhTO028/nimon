import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/local_story_draft_repository.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/data/story_draft_mapper.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart'
    show CreatorDraftResumeMeta, CreatorLastActiveModule;
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteStoryDraftRepository implements StoryDraftRepository {
  RemoteStoryDraftRepository({
    required String apiBaseUrl,
    http.Client? client,
    StoryDraftRepository? fallbackLocal,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'\/+$'), ''),
        _client = client ?? http.Client(),
        _local = fallbackLocal ?? const LocalStoryDraftRepository();

  final String _apiBaseUrl;
  final http.Client _client;
  final StoryDraftRepository _local;

  /// When strict remote drafts are enabled, we must not mask backend errors by
  /// returning successful local fallback results.
  bool get _strict => RemoteBackendConfig.strictRemoteDrafts;

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
    // Bubble server envelope as a string for now; UI already displays `toString()`.
    final msg = r.body.trim().isEmpty
        ? 'HTTP ${r.statusCode}'
        : 'HTTP ${r.statusCode}: ${r.body}';
    throw StateError(msg);
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
    return StorySentenceDto(
      id: (m['id'] as String?) ?? '',
      storyId: (m['storyId'] as String?) ?? '',
      orderIndex: (m['orderIndex'] as int?) ?? 0,
      japaneseText: (m['japaneseText'] as String?) ?? '',
      reading: m['reading'] as String?,
      furiganaSpans: const [],
      meanings: null,
      audioStartMs: m['audioStartMs'] as int?,
      audioEndMs: m['audioEndMs'] as int?,
      provenance: null,
    );
  }

  VocabularyKanjiEntryDto _vocabDtoFromJson(Map<String, Object?> m) {
    return VocabularyKanjiEntryDto(
      id: (m['id'] as String?) ?? '',
      termJapanese: (m['termJapanese'] as String?) ?? '',
      type: (m['type'] as String?) ?? 'vocab',
      reading: m['reading'] as String?,
      glosses: null,
      exampleSentence: m['exampleSentence'] as String?,
      exampleMeanings: null,
      examplePairs: const [],
      provenance: null,
    );
  }

  GrammarEntryDto _grammarDtoFromJson(Map<String, Object?> m) {
    return GrammarEntryDto(
      id: (m['id'] as String?) ?? '',
      headline: (m['headline'] as String?) ?? '',
      form: m['form'] as String?,
      meanings: null,
      usage: null,
      examples: const [],
      mistakeWrong: m['mistakeWrong'] as String?,
      mistakeCorrect: m['mistakeCorrect'] as String?,
      relatedNote: null,
      provenance: null,
    );
  }

  QuizEntryDto _quizDtoFromJson(Map<String, Object?> m) {
    return QuizEntryDto(
      id: (m['id'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      prompt: (m['prompt'] as String?) ?? '',
      options: [
        for (final x in ((m['options'] as List?) ?? const []))
          x is String ? x : x.toString(),
      ],
      correctIndex: (m['correctIndex'] as int?) ?? 0,
      explanations: null,
      sourceNote: m['sourceNote'] as String?,
      provenance: null,
    );
  }

  StoryAudioDto _audioDtoFromJson(Map<String, Object?> m) {
    return StoryAudioDto(
      id: (m['id'] as String?) ?? '',
      sourceUrl: m['sourceUrl'] as String?,
      localFileName: m['localFileName'] as String?,
      localPath: m['localPath'] as String?,
      localSizeBytes: m['localSizeBytes'] as int?,
      localExtension: m['localExtension'] as String?,
      displayName: m['displayName'] as String?,
      durationSeconds: m['durationSeconds'] as int?,
      provenance: null,
    );
  }

  Map<String, Object?> _dtoToJsonMap(StoryDraftDto dto) {
    return {
      'schemaVersion': dto.schemaVersion,
      'basics': _basicsToJson(dto.basics),
      'sentences': [for (final s in dto.sentences) _sentenceToJson(s)],
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

  Map<String, Object?> _sentenceToJson(StorySentenceDto s) => {
        'id': s.id,
        'storyId': s.storyId,
        'orderIndex': s.orderIndex,
        'japaneseText': s.japaneseText,
        'reading': s.reading,
        'furiganaSpans': const [],
        'meanings': null,
        'audioStartMs': s.audioStartMs,
        'audioEndMs': s.audioEndMs,
        'provenance': null,
      };

  Map<String, Object?> _vocabToJson(VocabularyKanjiEntryDto e) => {
        'id': e.id,
        'termJapanese': e.termJapanese,
        'type': e.type,
        'reading': e.reading,
        'glosses': null,
        'exampleSentence': e.exampleSentence,
        'exampleMeanings': null,
        'examplePairs': const [],
        'provenance': null,
      };

  Map<String, Object?> _grammarToJson(GrammarEntryDto e) => {
        'id': e.id,
        'headline': e.headline,
        'form': e.form,
        'meanings': null,
        'usage': null,
        'examples': const [],
        'mistakeWrong': e.mistakeWrong,
        'mistakeCorrect': e.mistakeCorrect,
        'relatedNote': null,
        'provenance': null,
      };

  Map<String, Object?> _quizToJson(QuizEntryDto e) => {
        'id': e.id,
        'category': e.category,
        'prompt': e.prompt,
        'options': e.options,
        'correctIndex': e.correctIndex,
        'explanations': null,
        'sourceNote': e.sourceNote,
        'provenance': null,
      };

  Map<String, Object?> _audioToJson(StoryAudioDto a) => {
        'id': a.id,
        'sourceUrl': a.sourceUrl,
        'localFileName': a.localFileName,
        'localPath': a.localPath,
        'localSizeBytes': a.localSizeBytes,
        'localExtension': a.localExtension,
        'displayName': a.displayName,
        'durationSeconds': a.durationSeconds,
        'provenance': null,
      };

  // ---------------------------------------------------------------------------
  // StoryDraftRepository implementation
  // ---------------------------------------------------------------------------

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) async {
    try {
      final resp = await _client.post(
        _u('/v1/story-drafts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'schemaVersion': 1}),
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
      final resp = await _client.get(_u('/v1/story-drafts/$id'));
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
      final resp = await _client.get(_u('/v1/story-drafts'));
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
      final resp = await _client.get(uri);
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
    final resp = await _client.get(_u('/v1/story-drafts/$id'));
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
    final resp = await _client.post(
      _u('/v1/story-drafts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
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

  /// Forces [StoryBasics.creatorOwnerId] to match [RemoteBackendConfig.devOwnerId] so Nest
  /// `owner_mismatch` checks pass (backend uses `DEV_OWNER_ID` or default UUID).
  CreatorStoryV1 _normalizeDevOwnerForRemoteSave(CreatorStoryV1 story) {
    final expected = RemoteBackendConfig.devOwnerId.trim();
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
  Future<CreatorStoryV1> saveDraft(CreatorStoryV1 draft) async {
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
        'RemoteBackendConfig.devOwnerId="${RemoteBackendConfig.devOwnerId}"',
        name: 'RemoteStoryDraftRepository',
      );

      // If the UI already flipped publishState, route through publish endpoints.
      final desiredState = persisted.publishState.storageKey;

      // Resolve If-Match from GET (authoritative; avoids stale SharedPreferences etags).
      // If the backend has no row yet (local-only draft), POST create with client draftId, then PUT.
      final etag = await _resolveRemoteEtagForSave(id, dto);

      final putPayload = _dtoToJsonMap(dto)
        ..['publishState'] = 'draft'; // publish is done via publish endpoints

      var sentIfMatch = etag.trim();
      http.Response putResp = await _client.put(
        _u('/v1/story-drafts/$id'),
        headers: {
          'Content-Type': 'application/json',
          'If-Match': sentIfMatch,
        },
        body: jsonEncode(putPayload),
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
        putResp = await _client.put(
          _u('/v1/story-drafts/$id'),
          headers: {
            'Content-Type': 'application/json',
            'If-Match': sentIfMatch,
          },
          body: jsonEncode(putPayload),
        );
      }

      // Stale If-Match (e.g. overlapping autosaves): apply server currentEtag, retry same local payload once.
      putResp = await _retryOnceOn409Conflict(
        draftId: id,
        operation: 'PUT draft content',
        firstResp: putResp,
        firstIfMatch: sentIfMatch,
        sendWithIfMatch: (match) => _client.put(
          _u('/v1/story-drafts/$id'),
          headers: {
            'Content-Type': 'application/json',
            'If-Match': match,
          },
          body: jsonEncode(putPayload),
        ),
      );

      await _throwIfNotOk(putResp);
      developer.log(
        'draftId=$id PUT content succeeded httpStatus=${putResp.statusCode}',
        name: 'RemoteStoryDraftRepository',
      );
      final putDto = _dtoFromJson(await _jsonObjectFromResponse(putResp));
      await _saveEtag(id, putDto.etag);

      if (desiredState == 'reading_only_published') {
        final roEtag = (putDto.etag != null && putDto.etag!.trim().isNotEmpty)
            ? putDto.etag!.trim()
            : await _tryFetchRemoteEtag(id);
        if (roEtag == null || roEtag.isEmpty) {
          if (_strict) {
            throw StateError(
              'RemoteStoryDraftRepository: missing If-Match before publishReadOnly for $id',
            );
          }
          return persisted;
        }
        var roSent = roEtag.trim();
        http.Response roResp = await _client.post(
          _u('/v1/story-drafts/$id/publish/read-only'),
          headers: {
            'Content-Type': 'application/json',
            'If-Match': roSent,
          },
          body: jsonEncode({}),
        );
        roResp = await _retryOnceOn409Conflict(
          draftId: id,
          operation: 'POST publish/read-only',
          firstResp: roResp,
          firstIfMatch: roSent,
          sendWithIfMatch: (match) => _client.post(
            _u('/v1/story-drafts/$id/publish/read-only'),
            headers: {
              'Content-Type': 'application/json',
              'If-Match': match,
            },
            body: jsonEncode({}),
          ),
        );
        await _throwIfNotOk(roResp);
        developer.log(
          'draftId=$id publish read-only succeeded httpStatus=${roResp.statusCode}',
          name: 'RemoteStoryDraftRepository',
        );
        final roDto = _dtoFromJson(await _jsonObjectFromResponse(roResp));
        await _saveEtag(id, roDto.etag);
        final domain = StoryDraftMapper.toDomain(roDto);
        return await _local.saveDraft(domain);
      }

      if (desiredState == 'full_learn_published') {
        final flEtag = (putDto.etag != null && putDto.etag!.trim().isNotEmpty)
            ? putDto.etag!.trim()
            : await _tryFetchRemoteEtag(id);
        if (flEtag == null || flEtag.isEmpty) {
          if (_strict) {
            throw StateError(
              'RemoteStoryDraftRepository: missing If-Match before publishFullLearn for $id',
            );
          }
          return persisted;
        }
        var flSent = flEtag.trim();
        http.Response flResp = await _client.post(
          _u('/v1/story-drafts/$id/publish/full-learn'),
          headers: {
            'Content-Type': 'application/json',
            'If-Match': flSent,
          },
          body: jsonEncode({}),
        );
        flResp = await _retryOnceOn409Conflict(
          draftId: id,
          operation: 'POST publish/full-learn',
          firstResp: flResp,
          firstIfMatch: flSent,
          sendWithIfMatch: (match) => _client.post(
            _u('/v1/story-drafts/$id/publish/full-learn'),
            headers: {
              'Content-Type': 'application/json',
              'If-Match': match,
            },
            body: jsonEncode({}),
          ),
        );
        await _throwIfNotOk(flResp);
        developer.log(
          'draftId=$id publish full-learn succeeded httpStatus=${flResp.statusCode}',
          name: 'RemoteStoryDraftRepository',
        );
        final flDto = _dtoFromJson(await _jsonObjectFromResponse(flResp));
        await _saveEtag(id, flDto.etag);
        final domain = StoryDraftMapper.toDomain(flDto);
        return await _local.saveDraft(domain);
      }

      // No publish: just return updated from PUT.
      final domain = StoryDraftMapper.toDomain(putDto);
      return await _local.saveDraft(domain);
    } catch (e, st) {
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
      final resp = await _client.delete(_u('/v1/story-drafts/$id'));
      await _throwIfNotOk(resp);
      await _saveEtag(id, null);
      await _local.deleteDraft(id);
    } catch (e, st) {
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
