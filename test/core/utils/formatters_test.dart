import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/utils/formatters.dart';

void main() {
  group('splitCoarseDuration', () {
    test('零与不足一分钟都拆成 (0, 0)', () {
      expect(Formatters.splitCoarseDuration(0), (hours: 0, minutes: 0));
      // 59.9 秒不进位成 1 分：整分钟向下取整，不是四舍五入。
      expect(Formatters.splitCoarseDuration(59.9), (hours: 0, minutes: 0));
    });

    test('分钟与小时的进位边界', () {
      expect(Formatters.splitCoarseDuration(60), (hours: 0, minutes: 1));
      expect(Formatters.splitCoarseDuration(3599), (hours: 0, minutes: 59));
      expect(Formatters.splitCoarseDuration(3600), (hours: 1, minutes: 0));
    });

    test('分钟取的是小时的余数，不是总分钟数', () {
      // 331620 秒 = 92 小时 7 分。若误写成 total ~/ 60 会得到 5527 分。
      expect(Formatters.splitCoarseDuration(331620), (hours: 92, minutes: 7));
    });

    test('负数与非有限值一律按 0，不抛异常', () {
      expect(Formatters.splitCoarseDuration(-5), (hours: 0, minutes: 0));
      expect(Formatters.splitCoarseDuration(double.nan), (
        hours: 0,
        minutes: 0,
      ));
      expect(Formatters.splitCoarseDuration(double.infinity), (
        hours: 0,
        minutes: 0,
      ));
      expect(Formatters.splitCoarseDuration(double.negativeInfinity), (
        hours: 0,
        minutes: 0,
      ));
    });

    test('与 formatDuration 语义不同：后者仍渲染 hh:mm:ss', () {
      // 护栏：两个函数各有用途，别在汇总场景误用 formatDuration。
      expect(Formatters.formatDuration(331620), '92:07:00');
    });
  });

  group('formatFileSize', () {
    test('各量级单位', () {
      expect(Formatters.formatFileSize(512), '512 B');
      expect(Formatters.formatFileSize(1536), '1.5 KB');
      expect(Formatters.formatFileSize(5 * 1024 * 1024), '5.0 MB');
      expect(Formatters.formatFileSize(90409742336), '84.2 GB');
    });

    test('0 字节会渲染成「0 B」——所以统计面板要门控这一行', () {
      expect(Formatters.formatFileSize(0), '0 B');
    });
  });
}
