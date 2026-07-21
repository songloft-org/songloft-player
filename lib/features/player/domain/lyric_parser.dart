/// 逐字歌词中的单个字/词
///
/// [start] / [end] 均为**绝对**时间（已叠加所在行的行首时间戳），
/// 供渲染层按播放进度做逐字渐进高亮。[text] 可能含尾随空格（归属前一字）。
class LyricWord {
  final Duration start;
  final Duration end;
  final String text;

  const LyricWord({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  String toString() => 'LyricWord($start-$end: $text)';
}

/// 歌词行数据模型
class LyricLine {
  /// 歌词时间点
  final Duration time;

  /// 歌词文本（逐字行为各字文本拼接，供降级渲染 / 字幕 / 通知栏使用）
  final String text;

  /// 逐字数据。为 null 表示普通行（无逐字信息），非空表示可逐字高亮。
  final List<LyricWord>? words;

  /// 对齐的翻译歌词（tlyric），可为 null。
  final String? translation;

  /// 对齐的罗马音歌词（rlyric），可为 null。
  final String? romaji;

  const LyricLine({
    required this.time,
    required this.text,
    this.words,
    this.translation,
    this.romaji,
  });

  /// 是否携带可用的逐字数据。
  bool get hasWords => words != null && words!.isNotEmpty;

  /// 逐字行的结束时间（最后一字的 end）；普通行为 null。
  Duration? get endTime => hasWords ? words!.last.end : null;

  LyricLine copyWith({String? translation, String? romaji}) => LyricLine(
        time: time,
        text: text,
        words: words,
        translation: translation ?? this.translation,
        romaji: romaji ?? this.romaji,
      );

  @override
  String toString() => 'LyricLine(time: $time, text: $text)';
}

/// LRC 歌词解析器
class LyricParser {
  /// 解析 LRC 格式歌词
  ///
  /// 支持标准 LRC 格式：[mm:ss.xx]歌词文本
  /// 支持多个时间标签对应同一行歌词：[00:01.00][00:02.00]歌词文本
  static List<LyricLine> parse(String lrcContent) {
    final List<LyricLine> lyrics = [];
    final lines = lrcContent.split('\n');

    // 匹配时间标签的正则表达式：[mm:ss.xx] 或 [mm:ss]
    final timeRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 查找所有时间标签
      final matches = timeRegex.allMatches(trimmedLine).toList();
      if (matches.isEmpty) continue;

      // 提取歌词文本（去除所有时间标签后的内容）
      String text = trimmedLine;
      for (final match in matches.reversed) {
        text = text.replaceRange(match.start, match.end, '');
      }
      text = text.trim();

      // 跳过空歌词行（保留空行不影响功能，但可以选择跳过）
      // 为每个时间标签创建一个歌词行
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisecondsStr = match.group(3);

        // 处理毫秒：可能是 1-3 位数字
        int milliseconds = 0;
        if (millisecondsStr != null) {
          // 补齐到 3 位数字
          final padded = millisecondsStr.padRight(3, '0');
          milliseconds = int.parse(padded);
        }

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lyrics.add(LyricLine(time: time, text: text));
      }
    }

    // 按时间排序
    lyrics.sort((a, b) => a.time.compareTo(b.time));

    return lyrics;
  }

  /// 将无时间戳的纯文本歌词按行拆成静态 [LyricLine]（time 均为 0，无逐字数据）。
  ///
  /// 供 [parse] 解析不到任何时间标签、但内容非空时降级：例如 lrclib 只有
  /// plainLyrics 无 syncedLyrics 时，插件会回退纯文本歌词。此时按行静态展示，
  /// 不做逐行高亮/自动滚动（由 Provider 侧置 synced=false 控制）。
  static List<LyricLine> parsePlain(String content) {
    final lines = <LyricLine>[];
    for (final raw in content.split('\n')) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      lines.add(LyricLine(time: Duration.zero, text: t));
    }
    return lines;
  }

  /// 行首（单括号）时间标签，锚定行首，天然不会误匹配逐字用的 `[[...]]`。
  static final RegExp _lineTimeRegex =
      RegExp(r'^\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

  /// 洛雪相对偏移逐字标记：`<起始ms,持续ms>` + 其后文本（到下一个 `<` 为止）。
  static final RegExp _lxWordRegex = RegExp(r'<(\d+),(\d+)>([^<]*)');

  /// 绝对时间戳逐字标记：`[[mm:ss.xx]]` + 其后文本（到下一个 `[` 为止）。
  static final RegExp _absWordRegex =
      RegExp(r'\[\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\]([^\[]*)');

  /// 判断一段歌词文本是否包含逐字标记（洛雪相对或绝对双括号）。
  ///
  /// 供 Provider 决定：`lyric` 字段本身是否已内嵌逐字信息。
  static bool containsWordByWord(String content) {
    return content.contains('[[') || _lxWordRegex.hasMatch(content);
  }

  /// 解析逐字歌词，兼容两种格式：
  /// - 洛雪相对偏移：`[mm:ss.xxx]<off,dur>字<off,dur>字...`（off/dur 为相对该行的毫秒）
  /// - 绝对时间戳：`[mm:ss.xx][[mm:ss.xx]]字 [[mm:ss.xx]]字...`（每字双括号绝对时间）
  ///
  /// 无逐字标记的行降级为普通 [LyricLine]（words 为 null）。
  /// 绝对格式中每字的 end 取下一字的 start；行内最后一字的 end 在跨行阶段
  /// 用下一行的行首时间补齐，末行兜底为 start + 4s。
  static List<LyricLine> parseWordByWord(String content) {
    final List<LyricLine> lyrics = [];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      // 提取行首时间（若以 `[[` 开头则无独立行时间，后续用首字时间兜底）
      final ltMatch = _lineTimeRegex.firstMatch(line);
      Duration? lineTime;
      String body = line;
      if (ltMatch != null) {
        lineTime = _durationFrom(
          ltMatch.group(1)!,
          ltMatch.group(2)!,
          ltMatch.group(3),
        );
        body = line.substring(ltMatch.end);
      }

      List<LyricWord>? words;
      if (_lxWordRegex.hasMatch(body)) {
        words = _parseLxWords(body, lineTime ?? Duration.zero);
      } else if (body.contains('[[')) {
        words = _parseAbsWords(body);
      }

      if (words != null && words.isNotEmpty) {
        lyrics.add(LyricLine(
          time: lineTime ?? words.first.start,
          text: words.map((w) => w.text).join(),
          words: words,
        ));
      } else if (ltMatch != null) {
        // 有行首时间但无逐字标记 → 普通行
        lyrics.add(LyricLine(time: lineTime!, text: body.trim()));
      }
      // 既无行时间又无逐字标记的行（元数据/空行）直接跳过
    }

    lyrics.sort((a, b) => a.time.compareTo(b.time));

    // 跨行补齐绝对格式每行最后一字的 end（用下一行行首时间；末行兜底 +4s）
    for (var i = 0; i < lyrics.length; i++) {
      final line = lyrics[i];
      final ws = line.words;
      if (ws == null || ws.isEmpty) continue;
      final last = ws.last;
      if (last.end > last.start) continue; // 已有有效 end（洛雪格式或已补齐）
      final fallbackEnd = i + 1 < lyrics.length
          ? lyrics[i + 1].time
          : last.start + const Duration(seconds: 4);
      ws[ws.length - 1] = LyricWord(
        start: last.start,
        end: fallbackEnd > last.start ? fallbackEnd : last.start,
        text: last.text,
      );
    }

    return lyrics;
  }

  /// 解析洛雪相对偏移逐字：`<off,dur>text`，时间叠加行首时间。
  static List<LyricWord> _parseLxWords(String body, Duration lineTime) {
    final words = <LyricWord>[];
    for (final m in _lxWordRegex.allMatches(body)) {
      final off = int.parse(m.group(1)!);
      final dur = int.parse(m.group(2)!);
      final text = m.group(3) ?? '';
      if (text.isEmpty) continue;
      final start = lineTime + Duration(milliseconds: off);
      words.add(LyricWord(
        start: start,
        end: start + Duration(milliseconds: dur),
        text: text,
      ));
    }
    return words;
  }

  /// 解析绝对时间戳逐字：`[[mm:ss.xx]]text`。每字 end 先置为 start
  /// （标记「待补齐」），随后用下一字 start 填充；行内最后一字留到跨行阶段补齐。
  static List<LyricWord> _parseAbsWords(String body) {
    final matches = _absWordRegex.allMatches(body).toList();
    final starts = <Duration>[];
    final texts = <String>[];
    for (final m in matches) {
      final t = _durationFrom(m.group(1)!, m.group(2)!, m.group(3));
      final text = m.group(4) ?? '';
      if (text.isEmpty) continue;
      starts.add(t);
      texts.add(text);
    }
    final words = <LyricWord>[];
    for (var i = 0; i < starts.length; i++) {
      final isLast = i == starts.length - 1;
      words.add(LyricWord(
        start: starts[i],
        // 非末字 end 取下一字 start；末字暂置为 start，跨行阶段补齐
        end: isLast ? starts[i] : starts[i + 1],
        text: texts[i],
      ));
    }
    return words;
  }

  /// 把翻译（tlyric）与罗马音（rlyric）按时间对齐挂到主歌词行上。
  ///
  /// 均按普通 LRC 解析后，为每个主行寻找时间最接近且在 [tolerance] 内的译文行。
  static List<LyricLine> mergeTranslations(
    List<LyricLine> base, {
    String? tlyric,
    String? rlyric,
    Duration tolerance = const Duration(milliseconds: 600),
  }) {
    final tLines = (tlyric != null && tlyric.trim().isNotEmpty)
        ? parse(tlyric)
        : const <LyricLine>[];
    final rLines = (rlyric != null && rlyric.trim().isNotEmpty)
        ? parse(rlyric)
        : const <LyricLine>[];
    if (tLines.isEmpty && rLines.isEmpty) return base;

    String? nearest(List<LyricLine> lines, Duration t) {
      if (lines.isEmpty) return null;
      var bestIdx = -1;
      var bestDiff = tolerance;
      for (var i = 0; i < lines.length; i++) {
        final diff = (lines[i].time - t).abs();
        if (diff <= bestDiff) {
          bestDiff = diff;
          bestIdx = i;
        }
      }
      if (bestIdx < 0) return null;
      final text = lines[bestIdx].text.trim();
      return text.isEmpty ? null : text;
    }

    return [
      for (final line in base)
        line.copyWith(
          translation: nearest(tLines, line.time),
          romaji: nearest(rLines, line.time),
        ),
    ];
  }

  /// 从 mm/ss/毫秒串构造 Duration，毫秒补齐到 3 位。
  static Duration _durationFrom(String mm, String ss, String? msStr) {
    final ms = msStr == null ? 0 : int.parse(msStr.padRight(3, '0'));
    return Duration(
      minutes: int.parse(mm),
      seconds: int.parse(ss),
      milliseconds: ms,
    );
  }

  /// 把已解析的 LyricLine 列表反向序列化成 LRC 文本。
  ///
  /// 输出形如 `[mm:ss.xxx]text\n`，毫秒固定 3 位补零；
  /// 调用方传入的列表会先按 time 排序拷贝，原列表不被修改。
  /// 时间为负的行会被截断到 Duration.zero（不应该发生，作为防御性兜底）。
  static String stringify(List<LyricLine> lines) {
    if (lines.isEmpty) return '';
    final sorted = [...lines]..sort((a, b) => a.time.compareTo(b.time));
    final buf = StringBuffer();
    for (final l in sorted) {
      final t = l.time < Duration.zero ? Duration.zero : l.time;
      final totalMs = t.inMilliseconds;
      final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((totalMs ~/ 1000) % 60).toString().padLeft(2, '0');
      final ms = (totalMs % 1000).toString().padLeft(3, '0');
      buf.write('[$minutes:$seconds.$ms]');
      buf.write(l.text);
      buf.write('\n');
    }
    return buf.toString();
  }

  /// 整体平移歌词时间戳（含逐字每字时间）。负偏移导致时间小于 0 时截断到 Duration.zero。
  static List<LyricLine> applyOffset(List<LyricLine> lines, Duration offset) {
    Duration clamp(Duration d) => d < Duration.zero ? Duration.zero : d;
    return [
      for (final l in lines)
        LyricLine(
          time: clamp(l.time + offset),
          text: l.text,
          words: l.words == null
              ? null
              : [
                  for (final w in l.words!)
                    LyricWord(
                      start: clamp(w.start + offset),
                      end: clamp(w.end + offset),
                      text: w.text,
                    ),
                ],
          translation: l.translation,
          romaji: l.romaji,
        ),
    ];
  }

  /// 根据当前播放位置查找应高亮的歌词行索引
  ///
  /// 返回当前时间点应该显示的歌词行索引
  /// 如果没有找到合适的歌词行，返回 -1
  static int findCurrentLine(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) return -1;

    // 如果当前位置在第一行歌词之前，返回 -1
    if (position < lyrics.first.time) return -1;

    // 二分查找最后一个时间 <= position 的歌词行
    int left = 0;
    int right = lyrics.length - 1;
    int result = 0;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (lyrics[mid].time <= position) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
  }
}
