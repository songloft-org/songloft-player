import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// native（dart:io）平台的 HLS trust-all 本地代理。
///
/// 背景（songloft-org/songloft#272）：开启「忽略 SSL 证书校验」后，普通歌曲经
/// just_audio 的本地代理（内部 Dart HttpClient 继承 HttpOverrides.global 的 trust-all）
/// 已能连自签服务器；但 HLS 电台不行——just_audio 的代理只按「单一 URL 的 path+query」
/// 注册一个 handler，m3u8 里的切片指向别的 path：相对 URL 会解析到本机未注册的 path 触发
/// 空指针、绝对 URL 会绕过代理直连自签源站，两者都失败。
///
/// 本代理针对性解决该问题：
/// - 绑定 `127.0.0.1:<随机端口>`，只服务本机。
/// - 用**无条件接受任意证书**的 [HttpClient] 拉上游（不依赖全局 HttpOverrides，独立可靠）。
/// - 上游是 m3u8 时，把里面**所有**子资源 URI（切片 / #EXT-X-KEY / #EXT-X-MAP /
///   #EXT-X-MEDIA / 变体播放列表等）解析为绝对地址后改写为「本机代理入口」，使原生播放器
///   拉取任何子资源都经本代理 → 全程 trust-all。
/// - 其它（切片/密钥）按字节透传，转发 Range、回传 206/Content-Range 支持 seek。
///
/// 仅在用户显式开启忽略校验时使用。桌面端直播不走此代理（保留 #249 的 hlsDirect 直连源站
/// 逻辑，避免回归）。
class InsecureMediaProxy {
  InsecureMediaProxy._();

  static final InsecureMediaProxy instance = InsecureMediaProxy._();

  HttpServer? _server;
  Future<void>? _starting;

  /// id → 上游绝对 URI 的映射。用 [LinkedHashMap] 的插入序做 FIFO 淘汰，
  /// 防止直播播放列表反复刷新导致映射无限增长。
  final Map<int, Uri> _byId = <int, Uri>{};
  final Map<String, int> _byUrl = <String, int>{};
  int _counter = 0;
  static const int _maxEntries = 4096;

  late final HttpClient _client = _createTrustAllClient();

  static HttpClient _createTrustAllClient() {
    final client = HttpClient();
    // 无条件接受任意证书（仅在用户显式开启忽略校验时才会用到本代理）。
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 20);
    client.idleTimeout = const Duration(seconds: 30);
    // 用一个通用 UA，避免部分源站对空 UA 返回 403。
    client.userAgent =
        'Mozilla/5.0 (compatible; SongloftPlayer) AppleWebKit/537.36';
    return client;
  }

  Future<void> _ensureStarted() {
    if (_server != null) return Future<void>.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(
      _handle,
      onError: (Object e, StackTrace st) {
        debugPrint('[InsecureMediaProxy] server error (ignored): $e');
      },
      cancelOnError: false,
    );
    debugPrint('[InsecureMediaProxy] listening on 127.0.0.1:${server.port}');
  }

  /// 为一个 HLS 播放列表 [url] 返回一个本机代理入口 URL（http，末尾保留 `.m3u8`
  /// 供原生播放器识别为 HLS）。原生播放器拉取该入口后即进入本代理的改写流程。
  Future<String> wrapHls(String url) async {
    await _ensureStarted();
    final upstream = Uri.parse(url);
    return _entry(upstream, forceHlsSuffix: true);
  }

  /// 登记 [upstream] 并生成本机代理入口 URL：`http://127.0.0.1:port/<id>/<name>`。
  /// [forceHlsSuffix] 为 true 时确保 name 以 `.m3u8` 结尾（供播放列表入口识别为 HLS）。
  String _entry(Uri upstream, {bool forceHlsSuffix = false}) {
    final id = _register(upstream);
    var name = upstream.pathSegments.isNotEmpty
        ? upstream.pathSegments.last
        : 'res';
    if (name.isEmpty) name = 'res';
    if (forceHlsSuffix && !name.toLowerCase().endsWith('.m3u8')) {
      name = 'playlist.m3u8';
    }
    final port = _server!.port;
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      pathSegments: ['$id', name],
    ).toString();
  }

  int _register(Uri upstream) {
    final key = upstream.toString();
    final existing = _byUrl[key];
    if (existing != null) return existing;
    final id = _counter++;
    _byId[id] = upstream;
    _byUrl[key] = id;
    if (_byId.length > _maxEntries) {
      final oldestId = _byId.keys.first;
      final oldest = _byId.remove(oldestId);
      if (oldest != null) _byUrl.remove(oldest.toString());
    }
    return id;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final segments = request.uri.pathSegments;
      final id = segments.isNotEmpty ? int.tryParse(segments.first) : null;
      final upstream = id == null ? null : _byId[id];
      if (upstream == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      await _proxy(request, upstream);
    } catch (e, st) {
      debugPrint('[InsecureMediaProxy] handle error: $e\n$st');
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _proxy(HttpRequest request, Uri upstream) async {
    final isHead = request.method == 'HEAD';
    final clientReq = await _client.openUrl('GET', upstream);
    clientReq.followRedirects = true;
    clientReq.maxRedirects = 20;
    // 转发 Range，让切片/大文件 seek 生效。
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) clientReq.headers.set(HttpHeaders.rangeHeader, range);

    final upstreamResp = await clientReq.close();
    final effective = _effectiveUri(upstream, upstreamResp);
    final response = request.response;

    if (_isHlsResponse(effective, upstreamResp)) {
      // 播放列表：读全文 → 改写所有子资源 URI 经本代理 → 回传。
      final body = await upstreamResp.transform(utf8.decoder).join();
      final rewritten = rewriteHlsPlaylist(
        body,
        effective,
        (abs) => _entry(abs, forceHlsSuffix: _looksLikeHls(abs)),
      );
      final bytes = utf8.encode(rewritten);
      response.statusCode = HttpStatus.ok;
      response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl');
      response.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      if (!isHead) response.add(bytes);
      await response.close();
      return;
    }

    // 其它资源（切片 / key / 音频体）：透传状态码与关键响应头 + 字节流。
    response.statusCode = upstreamResp.statusCode;
    _copyHeader(upstreamResp, response, HttpHeaders.contentTypeHeader);
    _copyHeader(upstreamResp, response, HttpHeaders.contentRangeHeader);
    _copyHeader(upstreamResp, response, HttpHeaders.acceptRangesHeader);
    final len = upstreamResp.headers.value(HttpHeaders.contentLengthHeader);
    if (len != null) {
      response.headers.set(HttpHeaders.contentLengthHeader, len);
    }
    if (isHead) {
      await upstreamResp.drain<void>();
      await response.close();
      return;
    }
    await response.addStream(upstreamResp);
    await response.close();
  }

  Uri _effectiveUri(Uri requested, HttpClientResponse resp) {
    var eff = requested;
    for (final r in resp.redirects) {
      eff = eff.resolveUri(r.location);
    }
    return eff;
  }

  bool _isHlsResponse(Uri effective, HttpClientResponse resp) {
    final ct = resp.headers.contentType;
    if (ct != null) {
      final mime = '${ct.primaryType}/${ct.subType}'.toLowerCase();
      if (mime.contains('mpegurl')) return true;
      // 明确的音视频/字节类型则不当作播放列表。
      if (mime.startsWith('audio/') ||
          mime.startsWith('video/') ||
          mime == 'application/octet-stream') {
        return false;
      }
    }
    return _looksLikeHls(effective);
  }

  static bool _looksLikeHls(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }

  void _copyHeader(HttpClientResponse from, HttpResponse to, String name) {
    final v = from.headers.value(name);
    if (v != null) to.headers.set(name, v);
  }
}

/// 改写一段 HLS 播放列表文本：把其中所有子资源引用（切片行、变体播放列表行，以及以
/// `URI="..."` 形式出现的 #EXT-X-KEY / #EXT-X-MAP / #EXT-X-MEDIA / #EXT-X-PART /
/// #EXT-X-PRELOAD-HINT / #EXT-X-RENDITION-REPORT / #EXT-X-DATERANGE 的 X-ASSET-URI 等）
/// 先按 [base] 解析为绝对 URI，再经 [wrap] 转成本机代理入口 URL。
///
/// 纯函数（不触碰 dart:io），便于单元测试。
@visibleForTesting
String rewriteHlsPlaylist(
  String body,
  Uri base,
  String Function(Uri absolute) wrap,
) {
  final uriAttr = RegExp('URI="([^"]*)"');
  final lines = body.split('\n');
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // 保留原始行尾的 \r（split('\n') 后 CRLF 会残留 \r）。
    final hasCr = line.endsWith('\r');
    final content = hasCr ? line.substring(0, line.length - 1) : line;
    final trimmed = content.trim();
    String rewritten;
    if (trimmed.isEmpty) {
      rewritten = content;
    } else if (trimmed.startsWith('#')) {
      // 标签行：只改写内嵌的 URI="..."（含 X-ASSET-URI="..." 等以 URI=" 结尾的属性）。
      rewritten = content.replaceAllMapped(uriAttr, (m) {
        final ref = m.group(1) ?? '';
        if (ref.isEmpty) return m.group(0)!;
        return 'URI="${wrap(base.resolve(ref))}"';
      });
    } else {
      // 资源 URI 行（切片或变体播放列表）：整行改写。
      rewritten = wrap(base.resolve(trimmed));
    }
    out.write(rewritten);
    if (hasCr) out.write('\r');
    if (i != lines.length - 1) out.write('\n');
  }
  return out.toString();
}
