import 'package:flutter/foundation.dart';

/// 封面加载诊断日志（songloft-org/songloft#309）。
///
/// Web 端封面「滚回/队列重建后空白」曾长期难定位，因为失败是**静默**的（无异常）。
/// 这里统一在封面组件的 errorWidget 里记录失败 URL 与错误，`main.dart` 已把 debugPrint
/// 重定向进文件日志，故「导出日志」即可看到 `[Cover]` 记录，便于后续排查。
///
/// 为避免大歌单整屏失败时刷屏，做**每 URL 去重 + 总量上限**的轻量节流。
class CoverDiagnostics {
  CoverDiagnostics._();

  static final Set<String> _loggedUrls = <String>{};
  static int _loggedCount = 0;

  /// 单次会话最多记录的封面错误条数上限（防刷屏）。
  static const int _maxLogged = 200;

  /// 记录一次封面加载失败。同一 URL 只记一次，超过上限后静默丢弃。
  static void logError(String url, Object? error) {
    if (_loggedCount >= _maxLogged) return;
    // 去掉 access_token，避免凭证明文落盘。
    final sanitized = _stripToken(url);
    if (!_loggedUrls.add(sanitized)) return;
    _loggedCount++;
    debugPrint('[Cover] 加载失败 url=$sanitized error=$error');
    if (_loggedCount == _maxLogged) {
      debugPrint('[Cover] 失败日志达上限 $_maxLogged 条，后续静默');
    }
  }

  static String _stripToken(String url) {
    return url.replaceAll(RegExp(r'access_token=[^&]*'), 'access_token=***');
  }
}
