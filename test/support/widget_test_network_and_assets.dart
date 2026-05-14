import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Minimal valid 1×1 PNG — used for fake HTTP image responses and asset loads.
final Uint8List kWidgetTestOneByOnePng = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Asset bundle that satisfies Flutter’s manifest lookups and returns a tiny PNG
/// for image assets (avoids missing-file failures in widget tests).
class WidgetTestPngAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('AssetManifest.json')) {
      final bytes = Uint8List.fromList('{}'.codeUnits);
      return ByteData.view(bytes.buffer);
    }
    if (key.endsWith('AssetManifest.bin')) {
      final data =
          const StandardMessageCodec().encodeMessage(<String, Object?>{});
      return data!;
    }
    return ByteData.view(kWidgetTestOneByOnePng.buffer);
  }
}

class _WidgetTestPngHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _WidgetTestFakeHttpClient();
}

class _WidgetTestFakeHttpClient implements HttpClient {
  bool _autoUncompress = true;

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool v) => _autoUncompress = v;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _WidgetTestFakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WidgetTestFakeHttpClientRequest implements HttpClientRequest {
  _WidgetTestFakeHttpClientRequest(this._url);

  final Uri _url;

  Uri get url => _url;

  @override
  Future<HttpClientResponse> close() async =>
      _WidgetTestFakeHttpClientResponse();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WidgetTestFakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final Uint8List _png = kWidgetTestOneByOnePng;

  @override
  int get statusCode => 200;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  int get contentLength => _png.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_png]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpHeaders get headers => _WidgetTestFakeHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WidgetTestFakeHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Routes all HTTP image loads to a 1×1 PNG (supports [NetworkImage] in tests).
void installWidgetTestHttpOverridesPng() {
  HttpOverrides.global = _WidgetTestPngHttpOverrides();
}

void uninstallWidgetTestHttpOverrides() {
  HttpOverrides.global = null;
}
