import 'dart:collection';
import 'dart:convert';

/// Web 平台的 FileLogger 实现。
///
/// Web 无法像原生那样把日志落盘到文件（无文件系统），改用**内存环形缓冲**保留最近日志，
/// 供「导出日志」功能读取（[readLogBytes]）。缓冲随页面刷新丢失——对「复现问题→立刻导出」
/// 的 issue 提交场景足够；跨刷新持久化（IndexedDB）成本不匹配收益，故不做。
class FileLogger {
  FileLogger._();

  /// 缓冲总字符上限，超出后从头部丢弃最旧行（约 2 MB）。
  static const int _maxChars = 2 * 1024 * 1024;

  static final Queue<String> _buffer = Queue<String>();
  static int _bufferChars = 0;

  /// 敏感 token 脱敏：与原生实现保持一致，抹掉 access_token / token 查询参数值。
  static final RegExp _tokenPattern = RegExp(
    r'((?:access_token|token)=)[^&\s]+',
    caseSensitive: false,
  );

  static String _redact(String line) =>
      line.replaceAllMapped(_tokenPattern, (m) => '${m[1]}***');

  static Future<void> init() async {}

  static void writeln(String line) {
    final now = DateTime.now();
    final ts =
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.${_pad3(now.millisecond)}';
    final entry = '[$ts] ${_redact(line)}';
    _buffer.addLast(entry);
    _bufferChars += entry.length + 1;
    while (_bufferChars > _maxChars && _buffer.isNotEmpty) {
      final removed = _buffer.removeFirst();
      _bufferChars -= removed.length + 1;
    }
  }

  static Future<void> flush() async {}

  static Future<void> close() async {}

  static String? get logFilePath => null;

  static String? get logDir => null;

  /// 返回当前内存缓冲的日志内容（UTF-8 字节），供导出打包。无日志时返回 null。
  static Future<List<int>?> readLogBytes() async {
    if (_buffer.isEmpty) return null;
    return utf8.encode('${_buffer.join('\n')}\n');
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');
}
