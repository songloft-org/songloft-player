import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/lyric_parser.dart';

void main() {
  group('LyricParser.stringify', () {
    test('formats time as [mm:ss.xxx]', () {
      const lines = [
        LyricLine(time: Duration(milliseconds: 1500), text: 'hello'),
        LyricLine(
          time: Duration(minutes: 1, seconds: 23, milliseconds: 456),
          text: 'world',
        ),
      ];
      expect(LyricParser.stringify(lines), '[00:01.500]hello\n[01:23.456]world\n');
    });

    test('sorts lines before serializing', () {
      const lines = [
        LyricLine(time: Duration(seconds: 5), text: 'b'),
        LyricLine(time: Duration(seconds: 2), text: 'a'),
      ];
      expect(LyricParser.stringify(lines), '[00:02.000]a\n[00:05.000]b\n');
    });

    test('clamps negative times to zero', () {
      const lines = [
        LyricLine(time: Duration(seconds: -3), text: 'x'),
      ];
      expect(LyricParser.stringify(lines), '[00:00.000]x\n');
    });

    test('parse(stringify(parse(lrc))) round-trips', () {
      const original = '[00:01.500]hello\n[01:23.456]world\n';
      final parsed = LyricParser.parse(original);
      final out = LyricParser.stringify(parsed);
      expect(LyricParser.parse(out).map((l) => l.time.inMilliseconds).toList(),
          [1500, 83456]);
    });

    test('returns empty string for empty input', () {
      expect(LyricParser.stringify(const []), '');
    });
  });

  group('LyricParser.parseWordByWord', () {
    test('parses 洛雪 relative-offset format', () {
      final lines = LyricParser.parseWordByWord(
        '[00:00.000]<0,36>测<36,36>试<50,60>歌<80,75>词',
      );
      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line.hasWords, isTrue);
      expect(line.text, '测试歌词');
      expect(line.time, Duration.zero);
      final words = line.words!;
      expect(words, hasLength(4));
      expect(words[0].text, '测');
      expect(words[0].start, Duration.zero);
      expect(words[0].end, const Duration(milliseconds: 36));
      expect(words[3].text, '词');
      expect(words[3].start, const Duration(milliseconds: 80));
      expect(words[3].end, const Duration(milliseconds: 155));
    });

    test('relative offsets are added to the line timestamp', () {
      final lines = LyricParser.parseWordByWord(
        '[01:00.000]<0,500>a<500,500>b',
      );
      final words = lines.single.words!;
      expect(words[0].start, const Duration(minutes: 1));
      expect(words[1].start, const Duration(minutes: 1, milliseconds: 500));
      expect(words[1].end, const Duration(minutes: 1, seconds: 1));
    });

    test('parses absolute double-bracket format', () {
      final lines = LyricParser.parseWordByWord(
        '[00:15.56][[00:15.56]]心 [[00:16.12]]跳[[00:16.51]]乱\n'
        '[00:19.63][[00:19.63]]梦[[00:20.11]]也',
      );
      expect(lines, hasLength(2));
      final first = lines[0];
      expect(first.time, const Duration(seconds: 15, milliseconds: 560));
      expect(first.hasWords, isTrue);
      expect(first.text, '心 跳乱');
      final words = first.words!;
      expect(words, hasLength(3));
      expect(words[0].text, '心 ');
      expect(words[0].start, const Duration(seconds: 15, milliseconds: 560));
      // 非末字 end 取下一字 start
      expect(words[0].end, const Duration(seconds: 16, milliseconds: 120));
      expect(words[1].end, const Duration(seconds: 16, milliseconds: 510));
      // 行内末字 end 用下一行行首时间补齐
      expect(words[2].text, '乱');
      expect(words[2].end, const Duration(seconds: 19, milliseconds: 630));
    });

    test('last word of last line falls back to +4s', () {
      final lines = LyricParser.parseWordByWord('[00:10.00][[00:10.00]]末');
      final w = lines.single.words!.single;
      expect(w.start, const Duration(seconds: 10));
      expect(w.end, const Duration(seconds: 14));
    });

    test('degrades plain lines to word-less LyricLine', () {
      final lines = LyricParser.parseWordByWord(
        '[00:01.00]plain line\n[00:02.00]<0,300>逐<300,300>字',
      );
      expect(lines, hasLength(2));
      expect(lines[0].hasWords, isFalse);
      expect(lines[0].text, 'plain line');
      expect(lines[1].hasWords, isTrue);
    });

    test('containsWordByWord detects both markups', () {
      expect(LyricParser.containsWordByWord('[00:00.00]<0,10>字'), isTrue);
      expect(LyricParser.containsWordByWord('[00:00.00][[00:00.00]]字'), isTrue);
      expect(LyricParser.containsWordByWord('[00:00.00]普通歌词'), isFalse);
    });
  });

  group('LyricParser.mergeTranslations', () {
    test('aligns translation and romaji by nearest timestamp', () {
      final base = LyricParser.parse('[00:01.00]hello\n[00:05.00]world');
      final merged = LyricParser.mergeTranslations(
        base,
        tlyric: '[00:01.05]你好\n[00:05.00]世界',
        rlyric: '[00:01.00]nǐ hǎo',
      );
      expect(merged[0].translation, '你好'); // 50ms 内对齐
      expect(merged[0].romaji, 'nǐ hǎo');
      expect(merged[1].translation, '世界');
      expect(merged[1].romaji, isNull);
    });

    test('drops translations outside tolerance', () {
      final base = LyricParser.parse('[00:01.00]hello');
      final merged = LyricParser.mergeTranslations(
        base,
        tlyric: '[00:10.00]太远了',
      );
      expect(merged[0].translation, isNull);
    });

    test('returns base unchanged when no translations given', () {
      final base = LyricParser.parse('[00:01.00]hello');
      final merged = LyricParser.mergeTranslations(base);
      expect(merged, same(base));
    });
  });

  group('LyricParser.applyOffset', () {
    test('shifts each line by given offset', () {
      const lines = [
        LyricLine(time: Duration(seconds: 1), text: 'a'),
        LyricLine(time: Duration(seconds: 2), text: 'b'),
      ];
      final shifted = LyricParser.applyOffset(lines, const Duration(milliseconds: 500));
      expect(shifted[0].time, const Duration(milliseconds: 1500));
      expect(shifted[1].time, const Duration(milliseconds: 2500));
    });

    test('shifts word timestamps too', () {
      final lines = LyricParser.parseWordByWord('[00:01.000]<0,500>a<500,500>b');
      final shifted =
          LyricParser.applyOffset(lines, const Duration(seconds: 1));
      final words = shifted.single.words!;
      // 基准行时间 1s + 偏移 1s = 2s
      expect(words[0].start, const Duration(seconds: 2));
      expect(words[1].end, const Duration(seconds: 3));
    });

    test('clamps negative result to zero', () {
      const lines = [
        LyricLine(time: Duration(milliseconds: 200), text: 'a'),
        LyricLine(time: Duration(seconds: 5), text: 'b'),
      ];
      final shifted =
          LyricParser.applyOffset(lines, const Duration(seconds: -1));
      expect(shifted[0].time, Duration.zero);
      expect(shifted[1].time, const Duration(seconds: 4));
    });

    test('preserves text', () {
      const lines = [LyricLine(time: Duration(seconds: 1), text: 'hello')];
      final shifted =
          LyricParser.applyOffset(lines, const Duration(milliseconds: 100));
      expect(shifted.single.text, 'hello');
    });
  });
}
