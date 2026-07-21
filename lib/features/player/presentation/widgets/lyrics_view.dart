import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../domain/lyric_parser.dart';
import '../lyric_adjust_page.dart';
import '../providers/lyric_provider.dart';
import '../providers/player_provider.dart';
import 'karaoke_line.dart';

/// 歌词显示组件
///
/// 从 [lyricStateProvider] 消费歌词状态，自动滚动到当前行并高亮显示。
/// 用户手动滚动时暂停自动滚动，几秒后自动恢复。
/// 点击歌词行可跳转到对应时间点播放。
///
/// 当 [editable] 为 true 且 [song] 是本地歌曲时，右上角显示「调整」按钮，
/// 点击进入 LyricAdjustPage 编辑歌词时间戳。保存后会自动重新拉取歌词。
class LyricsView extends ConsumerStatefulWidget {
  /// 当前播放位置（仍需接收，用于歌词行点击 seek）
  final Duration currentPosition;

  /// 点击歌词行时的回调，传入被点击行的时间点
  final ValueChanged<Duration>? onSeek;

  /// 关联的歌曲对象。仅当 [editable] 为 true 时用于决定是否展示「调整」按钮。
  final Song? song;

  /// 是否允许编辑歌词。即使为 true，也只有 song.type == 'local' 才会显示按钮。
  final bool editable;

  const LyricsView({
    super.key,
    required this.currentPosition,
    this.onSeek,
    this.song,
    this.editable = false,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();

  bool _isUserScrolling = false;
  Timer? _resumeTimer;
  int _lastScrolledIndex = -1;

  /// 每行统一高度，随是否含翻译/罗马音在 build 中动态计算。
  /// 保持统一便于用 `index * _lineHeight` 精确定位滚动。
  double _lineHeight = _mainRowHeight;

  static const double _mainRowHeight = 48.0;
  static const double _translationRowHeight = 22.0;
  static const double _romajiRowHeight = 20.0;
  static const Duration _resumeDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients) return;

    final targetOffset = index * _lineHeight;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onScroll() {
    if (_scrollController.position.isScrollingNotifier.value) {
      _onUserScrollStart();
    }
  }

  void _onUserScrollStart() {
    _isUserScrolling = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, _onResumeAutoScroll);
  }

  void _onResumeAutoScroll() {
    _isUserScrolling = false;
    final lyricState = ref.read(lyricStateProvider);
    if (lyricState.currentIndex >= 0) {
      _scrollToLine(lyricState.currentIndex);
    }
  }

  bool get _shouldShowEditButton {
    if (!widget.editable) return false;
    final s = widget.song;
    if (s == null || s.type != 'local') return false;
    final lyricState = ref.read(lyricStateProvider);
    // 纯文本歌词（无时间轴）无法调整时间戳，不展示「调整」入口。
    return lyricState.hasLyrics &&
        lyricState.synced &&
        !lyricState.isLoading &&
        !lyricState.loadFailed;
  }

  Future<void> _openAdjustPage() async {
    final song = widget.song;
    final lyricState = ref.read(lyricStateProvider);
    final lyricText = lyricState.rawLyricText;
    if (song == null || lyricText == null || lyricText.isEmpty) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LyricAdjustPage(
          song: song,
          originalLyric: lyricText,
        ),
      ),
    );

    if (saved == true && mounted) {
      ref.read(lyricStateProvider.notifier).invalidate();
    }
  }

  /// 手动重新抓取当前歌曲歌词（清缓存 + 绕过浏览器缓存重跑歌词搜索）。
  void _refetchLyrics() {
    ref.read(lyricStateProvider.notifier).refetch();
  }

  /// 当前歌曲是否具备可请求的歌词端点（无端点时不展示重新抓取入口）。
  bool get _canRefetch {
    final url = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.lyricUrl),
    );
    return url != null && url.isNotEmpty;
  }

  /// 加载失败 / 暂无歌词时的占位：提示文案 + 可选「重新抓取歌词」按钮。
  Widget _buildStatusPlaceholder(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          if (_canRefetch) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _refetchLyrics,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(AppLocalizations.of(context).playerLyricsRefetch),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建单行：主歌词（当前行有逐字数据时用 [KaraokeLine] 逐字高亮，否则行级高亮）
  /// + 可选翻译 / 罗马音子行。
  Widget _buildLine(ThemeData theme, LyricLine lyric, bool isCurrent,
      {bool plain = false}) {
    final primary = theme.colorScheme.primary;
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    // 纯文本歌词无「当前行」概念，整体用较高可读性的中性色静态展示。
    final plainColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);

    Widget main;
    if (isCurrent && lyric.hasWords) {
      main = KaraokeLine(
        line: lyric,
        activeColor: primary,
        inactiveColor: dim,
        fontSize: 18,
      );
    } else {
      final text = lyric.text;
      main = Text(
        text.isEmpty ? '...' : text,
        style: TextStyle(
          fontSize: plain ? 16 : (isCurrent ? 18 : 15),
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: plain ? plainColor : (isCurrent ? primary : dim),
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final children = <Widget>[main];
    final translation = lyric.translation;
    final romaji = lyric.romaji;
    // 罗马音置于原文与译文之间，符合常见排版
    if (romaji != null) {
      children.add(Text(
        romaji,
        style: TextStyle(
          fontSize: isCurrent ? 13 : 12,
          color: (isCurrent ? primary : dim).withValues(alpha: 0.75),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }
    if (translation != null) {
      children.add(Text(
        translation,
        style: TextStyle(
          fontSize: isCurrent ? 14 : 13,
          fontWeight: isCurrent ? FontWeight.w500 : FontWeight.normal,
          color: (isCurrent ? primary : dim).withValues(alpha: 0.85),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    if (children.length == 1) return main;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyricState = ref.watch(lyricStateProvider);

    if (lyricState.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).playerLyricsLoading,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (lyricState.loadFailed) {
      return _buildStatusPlaceholder(
        theme,
        AppLocalizations.of(context).playerLyricsLoadFailed,
      );
    }

    if (!lyricState.hasLyrics) {
      return _buildStatusPlaceholder(
        theme,
        AppLocalizations.of(context).playerLyricsEmpty,
      );
    }

    // 当行索引变化时自动滚动
    final currentIndex = lyricState.currentIndex;
    if (currentIndex != _lastScrolledIndex && !_isUserScrolling && currentIndex >= 0) {
      _lastScrolledIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isUserScrolling) {
          _scrollToLine(currentIndex);
        }
      });
    }

    final lyrics = lyricState.lyrics;
    final isPlain = !lyricState.synced;

    // 统一行高：轨道含翻译/罗马音时为所有行预留对应行高，保持等距，滚动定位精确。
    final hasTranslations = lyrics.any((l) => l.translation != null);
    final hasRomaji = lyrics.any((l) => l.romaji != null);
    _lineHeight = _mainRowHeight +
        (hasTranslations ? _translationRowHeight : 0) +
        (hasRomaji ? _romajiRowHeight : 0);

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = ((constraints.maxHeight - _lineHeight) / 2)
            .clamp(0.0, double.infinity);
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (notification.dragDetails != null) {
                _onUserScrollStart();
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: 24,
            ),
            itemExtent: _lineHeight,
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final lyric = lyrics[index];
              final isCurrent = index == currentIndex;

              return Semantics(
                button: true,
                label: AppLocalizations.of(context).playerLyricsSeekTo,
                child: GestureDetector(
                  onTap: () {
                    if (widget.onSeek != null) {
                      widget.onSeek!(lyric.time);
                      _isUserScrolling = false;
                      _resumeTimer?.cancel();
                    }
                  },
                  child: Container(
                    height: _lineHeight,
                    alignment: Alignment.center,
                    child: _buildLine(theme, lyric, isCurrent, plain: isPlain),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    final showEdit = _shouldShowEditButton;
    final showRefetch = _canRefetch;
    if (!showEdit && !showRefetch) return body;

    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showRefetch)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 22),
                    tooltip: AppLocalizations.of(context).playerLyricsRefetch,
                    color: theme.colorScheme.primary,
                    onPressed: _refetchLyrics,
                  ),
                if (showEdit)
                  IconButton(
                    icon: const Icon(Icons.tune, size: 22),
                    tooltip: AppLocalizations.of(context).playerAdjustLyrics,
                    color: theme.colorScheme.primary,
                    onPressed: _openAdjustPage,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
