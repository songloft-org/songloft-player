class Formatters {
  /// 格式化秒数为 mm:ss 或 hh:mm:ss
  static String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 把秒数拆成「整小时 + 余下整分钟」，供曲库总时长这类**粗粒度汇总**展示
  ///
  /// 刻意不复用 [formatDuration]：那个渲染 hh:mm:ss，读起来是「时间戳 / 单曲进度」；
  /// 曲库总时长要的是「92 小时 7 分」这种量级感知，几十首歌累计出来的秒数没人关心。
  ///
  /// 只返回数字、不拼字符串，把「h / min」还是「小时 / 分」的选择留给 l10n。
  /// 非有限值（NaN / Infinity）与负数一律按 0 处理——后端 `SUM(duration)` 理论上
  /// 非负，但一个脏值不该让首页统计面板抛异常。
  static ({int hours, int minutes}) splitCoarseDuration(double seconds) {
    final total = (seconds.isFinite && seconds > 0) ? seconds.floor() : 0;
    return (hours: total ~/ 3600, minutes: (total % 3600) ~/ 60);
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
