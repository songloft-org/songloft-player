import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> clearBrowserCache() async {
  // 在删除 Cache Storage 之前，先收集所有已缓存资源的 URL。
  // 浏览器有两层独立的缓存：
  //   1. Cache Storage API — Service Worker 管理的缓存，JS 可直接删除
  //   2. HTTP 缓存 — 受 Cache-Control max-age 控制，JS 无法直接清除
  // 仅清 Cache Storage 不够，还需用 fetch(cache:'reload') 逐个刷新 HTTP 缓存。
  final cachedUrls = <String>{};

  // Cache Storage API（window.caches）与 Service Worker API 仅在 secure context
  // （https 或 localhost/127.0.0.1）下存在；在明文 http://<局域网IP> 这类非安全
  // 上下文中，对应属性在运行时为 undefined。package:web 的 Dart 静态类型是非空的
  // CacheStorage / ServiceWorkerContainer，无法反映这一点，因此必须用 js_interop
  // 的 isDefinedAndNotNull 做运行时判空，否则直接调用会抛 TypeError。
  final caches = web.window.caches;
  if (caches.isDefinedAndNotNull) {
    try {
      final cacheNames = (await caches.keys().toDart).toDart;
      for (final name in cacheNames) {
        try {
          final cache = await caches.open(name.toDart).toDart;
          final requests = (await cache.keys().toDart).toDart;
          for (final request in requests) {
            cachedUrls.add(request.url);
          }
        } catch (_) {}
        await caches.delete(name.toDart).toDart;
      }
    } catch (_) {
      // Cache Storage API 不可用（如非安全上下文）
    }
  }

  final container = web.window.navigator.serviceWorker;
  if (container.isDefinedAndNotNull) {
    try {
      final registrations = (await container.getRegistrations().toDart).toDart;
      for (final reg in registrations) {
        await reg.unregister().toDart;
      }
    } catch (_) {
      // Service Worker API 可能不可用（如 HTTP 环境）
    }
  }

  // index.html 和 Flutter 引导文件可能只在 HTTP 缓存中而不在 Cache Storage，
  // 必须一并 force-refresh，否则 reload 仍会加载旧版本。
  final base = web.window.location.origin;
  final basePath = _getBasePath();
  for (final path in [
    basePath,
    '${basePath}index.html',
    '${basePath}flutter_bootstrap.js',
    '${basePath}flutter_service_worker.js',
    '${basePath}main.dart.js',
  ]) {
    cachedUrls.add('$base$path');
  }

  final init = web.RequestInit(cache: 'reload');
  for (final url in cachedUrls) {
    try {
      await web.window.fetch(url.toJS, init).toDart;
    } catch (_) {}
  }
}

String _getBasePath() {
  final path = web.window.location.pathname;
  // 对于子路径部署（如 /songloft/），保留完整前缀；根路径返回 '/'
  if (path.endsWith('/')) return path;
  final lastSlash = path.lastIndexOf('/');
  return lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '/';
}

void reloadPage() {
  web.window.location.reload();
}
