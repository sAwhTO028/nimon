import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/auth/auth_strict_unauthorized.dart';

typedef MediaUploadAuthHeaderBuilder = Future<Map<String, String>> Function();

/// Successful POST `/v1/media/upload/{cover|audio}` JSON body.
class MediaUploadResponse {
  const MediaUploadResponse({
    required this.url,
    required this.mediaType,
    required this.originalName,
    required this.sizeBytes,
    this.durationSeconds,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    final dur = json['durationSeconds'];
    int? durationInt;
    if (dur is num) {
      durationInt = dur.round();
    }
    final size = json['sizeBytes'];
    final sizeBytes = size is num ? size.round() : int.tryParse('$size') ?? 0;
    return MediaUploadResponse(
      url: '${json['url'] ?? ''}'.trim(),
      mediaType: '${json['mediaType'] ?? ''}'.trim(),
      originalName: '${json['originalName'] ?? ''}'.trim(),
      sizeBytes: sizeBytes,
      durationSeconds: durationInt,
    );
  }

  final String url;
  final String mediaType;
  final String originalName;
  final int sizeBytes;
  final int? durationSeconds;
}

/// User-facing failure for media uploads (no raw stack traces in [userMessage]).
class MediaUploadException implements Exception {
  MediaUploadException(this.userMessage, {this.statusCode});

  final String userMessage;
  final int? statusCode;

  @override
  String toString() => 'MediaUploadException: $userMessage';
}

class MediaUploadRepository {
  MediaUploadRepository({
    required String apiBaseUrl,
    http.Client? client,
    required MediaUploadAuthHeaderBuilder authHeaderBuilder,
  })  : _apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _authHeaderBuilder = authHeaderBuilder;

  final String _apiBaseUrl;
  final http.Client _client;
  final MediaUploadAuthHeaderBuilder _authHeaderBuilder;

  Uri _u(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<Map<String, String>> _authHeaders() async {
    final h = await _authHeaderBuilder();
    final auth = h['Authorization']?.trim() ?? '';
    if (auth.isEmpty) {
      throw MediaUploadException(
        'Sign in to upload media.',
        statusCode: null,
      );
    }
    return h;
  }

  String _friendlyHttpError(int code, String body) {
    switch (code) {
      case 400:
        return 'This file could not be uploaded. Check the format and try again.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 413:
        return 'This file is too large for upload.';
      case 415:
        return 'This file type is not supported for upload.';
      default:
        final t = body.trim();
        if (t.length > 200) {
          return 'Upload failed (HTTP $code).';
        }
        return t.isEmpty ? 'Upload failed (HTTP $code).' : t;
    }
  }

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    notifyIfStrictUnauthorized401(r);
    throw MediaUploadException(
      _friendlyHttpError(r.statusCode, r.body),
      statusCode: r.statusCode,
    );
  }

  Future<http.MultipartFile> _multipartFileFromXFile(XFile file) async {
    final name = file.name.trim().isEmpty ? 'upload.bin' : file.name.trim();
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return http.MultipartFile.fromBytes('file', bytes, filename: name);
    }
    final path = file.path.trim();
    if (path.isEmpty) {
      final bytes = await file.readAsBytes();
      return http.MultipartFile.fromBytes('file', bytes, filename: name);
    }
    return http.MultipartFile.fromPath('file', path, filename: name);
  }

  Future<MediaUploadResponse> uploadCover(XFile file) async {
    try {
      final headers = await _authHeaders();
      final uri = _u('/v1/media/upload/cover');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(headers);
      req.files.add(await _multipartFileFromXFile(file));
      final streamed = await _client.send(req);
      final resp = await http.Response.fromStream(streamed);
      _throwIfNotOk(resp);
      final map = jsonDecode(resp.body);
      if (map is! Map<String, dynamic>) {
        throw MediaUploadException('Unexpected response from server.');
      }
      final out = MediaUploadResponse.fromJson(map);
      if (out.url.isEmpty) {
        throw MediaUploadException('Upload succeeded but no URL was returned.');
      }
      return out;
    } on MediaUploadException {
      rethrow;
    } on http.ClientException {
      throw MediaUploadException(
        'Could not reach the server. Check your connection and API base URL.',
      );
    } on FormatException {
      throw MediaUploadException('Unexpected response from server.');
    } catch (_) {
      throw MediaUploadException(
        'Upload failed. Please try again.',
      );
    }
  }

  Future<MediaUploadResponse> uploadAudio({
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = _u('/v1/media/upload/audio');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(headers);
      final name = filename.trim().isEmpty ? 'audio.bin' : filename.trim();
      req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: name),
      );
      final streamed = await _client.send(req);
      final resp = await http.Response.fromStream(streamed);
      _throwIfNotOk(resp);
      final map = jsonDecode(resp.body);
      if (map is! Map<String, dynamic>) {
        throw MediaUploadException('Unexpected response from server.');
      }
      final out = MediaUploadResponse.fromJson(map);
      if (out.url.isEmpty) {
        throw MediaUploadException('Upload succeeded but no URL was returned.');
      }
      return out;
    } on MediaUploadException {
      rethrow;
    } on http.ClientException {
      throw MediaUploadException(
        'Could not reach the server. Check your connection and API base URL.',
      );
    } on FormatException {
      throw MediaUploadException('Unexpected response from server.');
    } catch (_) {
      throw MediaUploadException(
        'Upload failed. Please try again.',
      );
    }
  }

  /// Uses filesystem path on native when possible (streaming); otherwise bytes.
  Future<MediaUploadResponse> uploadAudioPlatformFile({
    required String filename,
    required String? path,
    required List<int>? bytes,
  }) async {
    final name = filename.trim().isEmpty ? 'audio.bin' : filename.trim();
    if (!kIsWeb && path != null && path.trim().isNotEmpty) {
      try {
        final headers = await _authHeaders();
        final uri = _u('/v1/media/upload/audio');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(headers);
        req.files.add(
          await http.MultipartFile.fromPath('file', path.trim(),
              filename: name),
        );
        final streamed = await _client.send(req);
        final resp = await http.Response.fromStream(streamed);
        _throwIfNotOk(resp);
        final map = jsonDecode(resp.body);
        if (map is! Map<String, dynamic>) {
          throw MediaUploadException('Unexpected response from server.');
        }
        final out = MediaUploadResponse.fromJson(map);
        if (out.url.isEmpty) {
          throw MediaUploadException(
              'Upload succeeded but no URL was returned.');
        }
        return out;
      } on MediaUploadException {
        rethrow;
      } on http.ClientException {
        throw MediaUploadException(
          'Could not reach the server. Check your connection and API base URL.',
        );
      } on FormatException {
        throw MediaUploadException('Unexpected response from server.');
      } catch (_) {
        throw MediaUploadException(
          'Upload failed. Please try again.',
        );
      }
    }
    final b = bytes;
    if (b == null || b.isEmpty) {
      throw MediaUploadException('Could not read the audio file.');
    }
    return uploadAudio(filename: name, bytes: b);
  }
}
