import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'dio_insecure.dart';
import 'server_entry.dart';

class ProbeResult {
  final ServerEntry entry;
  final bool ok;
  final int? statusCode;
  final String? error;

  const ProbeResult({
    required this.entry,
    required this.ok,
    this.statusCode,
    this.error,
  });
}

class ServerProbe {
  static const Duration _defaultTimeout = Duration(milliseconds: 2500);

  /// 并行探测所有 entries 的 `/api/v1/health`，返回**列表索引最小**的可达项。
  /// 全部失败返回 null。
  /// 优化：一旦能确定最高优先级可达服务器即立即返回，无需等待低优先级探测完成。
  static Future<ServerEntry?> pickFirstReachable(
    List<ServerEntry> entries, {
    Duration timeout = _defaultTimeout,
  }) async {
    if (entries.isEmpty) return null;

    final n = entries.length;
    final results = List<bool?>.filled(n, null);
    final completer = Completer<ServerEntry?>();

    void tryResolve() {
      if (completer.isCompleted) return;
      for (var i = 0; i < n; i++) {
        if (results[i] == null) return;
        if (results[i]!) {
          completer.complete(entries[i]);
          return;
        }
      }
      completer.complete(null);
    }

    for (var i = 0; i < n; i++) {
      final idx = i;
      probeOne(entries[idx], timeout: timeout).then((r) {
        results[idx] = r.ok;
        tryResolve();
      });
    }

    return completer.future;
  }

  /// 并行探测所有 entries，返回与输入顺序对应的结果列表。
  static Future<List<ProbeResult>> probeAll(
    List<ServerEntry> entries, {
    Duration timeout = _defaultTimeout,
  }) async {
    return Future.wait(
      entries.map((e) => probeOne(e, timeout: timeout)),
      eagerError: false,
    );
  }

  /// 探测单个 entry。失败折叠为 [ProbeResult.ok] = false，不抛异常。
  static Future<ProbeResult> probeOne(
    ServerEntry entry, {
    Duration timeout = _defaultTimeout,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: entry.url,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        headers: const {'Accept': 'application/json'},
      ),
    );
    // 忽略 SSL 证书校验时，探测也需放行自签证书（web 上为 no-op）
    if (AppConfig.insecureTls) {
      applyInsecureTls(dio);
    }
    try {
      final res = await dio.get<dynamic>('/api/v1/health');
      final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
      return ProbeResult(entry: entry, ok: ok, statusCode: res.statusCode);
    } catch (e) {
      debugPrint('[ServerProbe] ${entry.url} 不可达: $e');
      return ProbeResult(entry: entry, ok: false, error: e.toString());
    } finally {
      dio.close(force: true);
    }
  }
}
