import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/live_activity_service.dart';
import '../../../../core/storage/lyric_cache_service.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../features/settings/presentation/providers/settings_provider.dart';
import '../../../../main.dart';
import '../../domain/lyric_parser.dart';
import 'player_provider.dart';

/// 歌词状态
class LyricState {
  final List<LyricLine> lyrics;
  final int currentIndex;
  final bool isLoading;
  final bool loadFailed;
  final String? rawLyricText;

  const LyricState({
    this.lyrics = const [],
    this.currentIndex = -1,
    this.isLoading = false,
    this.loadFailed = false,
    this.rawLyricText,
  });

  /// 当前应高亮的歌词行对象（含逐字 words / 翻译 / 罗马音），无则为 null。
  LyricLine? get currentLine {
    if (currentIndex < 0 || currentIndex >= lyrics.length) return null;
    return lyrics[currentIndex];
  }

  String get currentLyricText {
    if (currentIndex < 0 || currentIndex >= lyrics.length) return '';
    return lyrics[currentIndex].text;
  }

  String get nextLyricText {
    final next = currentIndex + 1;
    if (next < 0 || next >= lyrics.length) return '';
    return lyrics[next].text;
  }

  bool get hasLyrics => lyrics.isNotEmpty;

  LyricState copyWith({
    List<LyricLine>? lyrics,
    int? currentIndex,
    bool? isLoading,
    bool? loadFailed,
    String? rawLyricText,
    bool clearRawLyricText = false,
  }) {
    return LyricState(
      lyrics: lyrics ?? this.lyrics,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
      rawLyricText:
          clearRawLyricText ? null : (rawLyricText ?? this.rawLyricText),
    );
  }
}

/// 歌词状态 Provider
///
/// 监听当前歌曲变化自动加载歌词，监听播放进度自动追踪当前行。
/// 仅在歌词行变化时通知下游，避免高频更新。
final lyricStateProvider = NotifierProvider<LyricNotifier, LyricState>(
  LyricNotifier.new,
);

class LyricNotifier extends Notifier<LyricState> {
  String? _lastLoadedUrl;

  @override
  LyricState build() {
    final lyricUrl = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.lyricUrl),
    );

    ref.listen(playerStateProvider.select((s) => s.currentTime), (prev, next) {
      _updateCurrentLine(next);
    });

    // 通知栏歌词显示位置切换时，若当前有歌词行则用新模式立即重推一次（即时生效，无需切歌）
    ref.listen(notificationLyricInTitleProvider, (prev, next) {
      final text = state.currentLyricText;
      if (text.isNotEmpty) {
        ref
            .read(audioHandlerProvider)
            .updateNowPlayingLyric(text, inTitle: next);
      }
    });

    if (lyricUrl != null && lyricUrl.isNotEmpty) {
      Future.microtask(() => _loadLyrics(lyricUrl));
      return const LyricState(isLoading: true);
    }

    _lastLoadedUrl = null;
    Future.microtask(() => ref.read(audioHandlerProvider).restoreNowPlaying());
    return const LyricState();
  }

  void _updateCurrentLine(Duration position) {
    if (state.lyrics.isEmpty) return;
    final newIndex = LyricParser.findCurrentLine(state.lyrics, position);
    if (newIndex != state.currentIndex) {
      state = state.copyWith(currentIndex: newIndex);
      LiveActivityService().updateLyric(
        state.currentLyricText,
        state.nextLyricText,
      );
      ref.read(audioHandlerProvider).updateNowPlayingLyric(
        state.currentLyricText,
        inTitle: ref.read(notificationLyricInTitleProvider),
      );
    }
  }

  Future<void> _loadLyrics(String? lyricUrl) async {
    if (lyricUrl == null || lyricUrl.isEmpty) {
      _lastLoadedUrl = null;
      state = const LyricState();
      return;
    }

    if (_lastLoadedUrl == lyricUrl && state.hasLyrics) return;

    state = state.copyWith(
      isLoading: true,
      loadFailed: false,
      lyrics: [],
      currentIndex: -1,
    );

    final cached = await LyricCacheService().get(lyricUrl);
    if (cached != null) {
      _applyPayload(lyricUrl, _decodeCached(cached));
      return;
    }

    try {
      final fullUrl = UrlHelper.buildLyricUrl(lyricUrl);
      final response = await Dio().get<Map<String, dynamic>>(fullUrl);

      final body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      _applyPayload(lyricUrl, body);

      // 缓存完整 payload（含逐字/翻译/罗马音），有主歌词或逐字才写入
      final main = _stringField(body, 'lyric');
      final lx = _stringField(body, 'lxlyric');
      if (main.isNotEmpty || lx.isNotEmpty) {
        await LyricCacheService().put(
          lyricUrl,
          jsonEncode({
            'lyric': main,
            'lxlyric': lx,
            'tlyric': _stringField(body, 'tlyric'),
            'rlyric': _stringField(body, 'rlyric'),
          }),
        );
      }
    } catch (e) {
      debugPrint('[LyricProvider] Failed to load lyric: $e');
      state = state.copyWith(isLoading: false, loadFailed: true);
    }
  }

  /// 从歌词 payload 解析出（可含逐字/翻译/罗马音的）歌词行并写入 state。
  void _applyPayload(String lyricUrl, Map<String, dynamic> body) {
    final main = _stringField(body, 'lyric');
    final lx = _stringField(body, 'lxlyric');

    // 逐字源：优先 lxlyric；否则若主歌词本身内嵌逐字标记则用主歌词
    String wbwSource = '';
    if (lx.isNotEmpty) {
      wbwSource = lx;
    } else if (main.isNotEmpty && LyricParser.containsWordByWord(main)) {
      wbwSource = main;
    }

    var lyrics = wbwSource.isNotEmpty
        ? LyricParser.parseWordByWord(wbwSource)
        : LyricParser.parse(main);
    lyrics = LyricParser.mergeTranslations(
      lyrics,
      tlyric: _nullableStringField(body, 'tlyric'),
      rlyric: _nullableStringField(body, 'rlyric'),
    );

    _lastLoadedUrl = lyricUrl;
    final position = ref.read(playerStateProvider).currentTime;
    final index = LyricParser.findCurrentLine(lyrics, position);
    state = LyricState(
      lyrics: lyrics,
      currentIndex: index,
      rawLyricText: main.isEmpty ? null : main,
    );
    LiveActivityService().updateLyric(
      state.currentLyricText,
      state.nextLyricText,
    );
    ref.read(audioHandlerProvider).updateNowPlayingLyric(
      state.currentLyricText,
      inTitle: ref.read(notificationLyricInTitleProvider),
    );
  }

  /// 解析缓存字符串：新格式为 payload JSON；旧格式为纯 LRC 文本（降级到 lyric 字段）。
  Map<String, dynamic> _decodeCached(String cached) {
    final trimmed = cached.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // 落到纯文本分支
      }
    }
    return {'lyric': cached};
  }

  static String _stringField(Map<String, dynamic> body, String key) {
    final v = body[key];
    return v is String ? v : '';
  }

  static String? _nullableStringField(Map<String, dynamic> body, String key) {
    final v = body[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  /// 强制重新加载歌词（歌词调整后调用）
  void invalidate() {
    _lastLoadedUrl = null;
    final lyricUrl = ref.read(playerStateProvider).currentSong?.lyricUrl;
    _loadLyrics(lyricUrl);
  }
}

/// 便捷 Provider：当前歌词行文本
final currentLyricTextProvider = Provider<String>((ref) {
  return ref.watch(lyricStateProvider).currentLyricText;
});

/// 便捷 Provider：下一行歌词文本
final nextLyricTextProvider = Provider<String>((ref) {
  return ref.watch(lyricStateProvider).nextLyricText;
});
