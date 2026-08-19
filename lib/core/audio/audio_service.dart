import 'dart:async';
import 'dart:io';

// LockCachingAudioSource 是 just_audio 中标记为实验性的边播边缓存 API，
// 目前没有稳定替代方案，此处有意使用以提升播放体验。
// ignore_for_file: experimental_member_use

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';
import '../../config/constants.dart';
import '../../features/playlist/domain/playlist.dart';
import '../network/insecure_media_proxy.dart';
import '../../shared/models/song.dart';
import '../storage/song_cache_service.dart';
import '../utils/audio_format_helper.dart';
import '../utils/url_helper.dart';
import 'media_browse_data_source.dart';

/// Songloft 音频处理器 - 集成 audio_service 实现通知栏控制
class SongloftAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Duration _liveLoadTimeout = Duration(seconds: 18);
  static const String _streamUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 Songloft/1.0';

  /// 通知栏/锁屏/灵动岛/桌面小组件艺术图的服务端缩略宽度（物理像素）。
  /// artUri 由系统/平台直接拉取，传 ?w= 避免每首歌拉全尺寸封面（3~4MB）加剧
  /// NAS 拥堵，与显示控件（d3012f6）一并对齐全平台缩略（songloft-org/songloft-player#39）。
  static const int _artUriWidth = 256;

  // 所有原生平台统一 media_kit(libmpv) 后端，EQ 走 mpv `af`（见 MpvEqualizerService），
  // 不再使用 just_audio 的 AndroidEqualizer / AudioPipeline androidAudioEffects——后者会让
  // just_audio 对平台 player 调 androidEqualizerGetParameters()，而 media_kit 的
  // SongloftMediaKitPlayer 不实现该 Android 专属方法，会致全曲无法播放（songloft-org/songloft#76）。
  late final ja.AudioPlayer _player = ja.AudioPlayer();

  String? _originalTitle;
  String? _originalArtist;

  /// 最近一次 [playSong] 的播放来源（本地缓存 / 远端流串），供 PlayerNotifier 回填
  /// 到 PlayerState，播放页「歌曲信息」据此展示。
  PlaybackSource lastPlaybackSource = PlaybackSource.unknown;

  /// 当前播放歌曲的 normalize 缓存文件路径（仅 normalize 开启时非 null）。
  /// 切歌时由 [clearIncompleteNormCache] 判定是否需要清理。
  File? _normCacheFile;

  /// 是否正连着 Bundle 内嵌本地后端（RunMode.local 的等价判定）。
  ///
  /// handler 无 Riverpod Ref 拿不到 runModeProvider，但本地模式的所有入口都把
  /// baseUrl 写成 127.0.0.1，故「bundle 构建 + 回环 host」可靠等价。
  /// 内嵌后端（尤其手机）无 ffmpeg，video-hls 会 503，此时视频保持直出。
  bool get _isLocalEmbeddedBackend {
    if (!AppConfig.hasEmbeddedBackend) return false;
    final host = Uri.tryParse(AppConfig.resolvedBaseUrl)?.host ?? '';
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  /// Web HLS 视频主控模式：video 元素接管播放，just_audio 不加载音源。
  bool hlsVideoPrimaryMode = false;

  /// Web HLS 视频的 URL（供 video 元素使用）。
  String? hlsVideoUrl;

  /// 回调：启动 Web HLS 视频播放（由 PlayerNotifier 注入，调用 WebVideoPlaybackNotifier）。
  void Function(String url)? onStartHlsVideo;

  /// 回调：停止 Web HLS 视频播放。
  VoidCallback? onStopHlsVideo;

  /// 回调：Web HLS 视频主控模式下的播放控制转发（play/pause/seek 由 video 元素承接）。
  /// 媒体会话按键 / 恢复播放进度等路径直接调 handler 方法，不经 PlayerNotifier
  /// 的分支判定，若不转发会落到无音源的 just_audio 上静默失效。
  VoidCallback? onPlayHlsVideo;
  VoidCallback? onPauseHlsVideo;
  void Function(Duration position)? onSeekHlsVideo;

  bool _isCurrentSongFavorited = false;

  /// 通知栏回调（由 PlayerNotifier 设置）
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  VoidCallback? onSongCompleted;
  VoidCallback? onToggleFavorite;

  /// Android Auto 媒体浏览数据源（由 PlayerNotifier 注入）
  MediaBrowseDataSource? mediaBrowseDataSource;

  /// Android Auto 浏览树点击播放回调（由 PlayerNotifier 注入）
  Future<void> Function(Song song)? onPlayFromBrowse;

  /// 切歌前主动通知后端"放弃旧 songID 工作"的钩子（由 PlayerNotifier 注入）。
  ///
  /// 后端 issue #79：just_audio 的 LockCachingAudioSource 在切歌时不会 abort 上游 HTTP，
  /// 导致后端无法靠 r.Context() 取消旧 song 的 prefetch/transcode/reassign。客户端切歌
  /// 之前调一下 POST /api/v1/songs/{id}/activate，后端立即让位。
  /// 失败被吞，绝不能让 activate 失败影响播放主路径。
  void Function(int songId)? notifySongActivated;

  /// 初始化 Future，用于确保初始化完成
  late final Future<void> _initFuture;

  late final StreamSubscription<PlaybackState> _playbackEventSub;
  late final StreamSubscription<PlaybackState> _playbackLogSub;
  late final StreamSubscription<ja.ProcessingState> _processingStateSub;
  late final StreamSubscription<bool> _playingStateSub;
  late final StreamSubscription<Object> _asyncErrorSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _disposed = false;

  SongloftAudioHandler() {
    // 使用 listen + add 而非 pipe()：pipe() 内部调用 addStream 独占 sink，
    // 导致 super.stop() 等方法无法再调用 playbackState.add()，
    // 退出时抛出 "You cannot add items while items are being added from addStream"。
    _playbackEventSub = _player.playbackEventStream
        .map(_transformEvent)
        .listen(playbackState.add);

    // media_kit(libmpv) 后端在 Android 上不像 ExoPlayer 那样对每次播放态切换都发
    // 平台 PlaybackEvent，靠 position tick 才顺带刷新——暂停后 tick 停止，playbackState
    // 里的 playing/position 可能停滞，导致系统媒体控件（通知栏/灵动岛）显示与实际不同步、
    // 控制按钮看似失效。额外订阅 playingStream，播放态一变就主动重播一次 playbackState，
    // 保证 audio_service 侧的 MediaSession 始终拿到最新状态（songloft-org/songloft-player#23）。
    _playingStateSub = _player.playingStream.distinct().listen((playing) {
      if (_disposed) return;
      debugPrint('[AudioService] 🎚️ playingStream 变化: playing=$playing');
      playbackState.add(_buildPlaybackState());
    });
    debugPrint('[AudioService] ✓ playbackEventStream 已绑定');

    // 监听 playbackState 变化，用于排查通知栏问题
    _playbackLogSub = playbackState.listen((state) {
      // 该日志随每个播放事件/进度 tick 高频触发，仅 debug 构建输出，
      // 避免 release 端日志文件被撑爆。
      if (kDebugMode) {
        debugPrint(
          '[AudioService] 📢 playbackState 更新: playing=${state.playing}, '
          'processingState=${state.processingState}, '
          'position=${state.updatePosition}, '
          'controls=${state.controls.length}个',
        );
      }
    });

    // 监听播放完成
    _processingStateSub = _player.processingStateStream.listen(
      (state) {
        if (_disposed) return;
        debugPrint('[AudioService] processingState 变化: $state');
        if (state == ja.ProcessingState.completed) {
          try {
            onSongCompleted?.call();
          } catch (e) {
            debugPrint('[AudioService] onSongCompleted error: $e');
            // 不重新抛出，避免 stream 断裂
          }
        }
      },
      onError: (error) {
        debugPrint('[AudioService] processingStateStream error: $error');
      },
    );

    // audio_service 在把 mediaItem / playbackState 推给原生侧时，**任何**原生异常都只是
    // 被静默投进 AudioService.asyncError（见 _observePlaybackState）。而原生 setState 里同步
    // 做了 startForeground(buildNotification())：一旦通知构建抛错（图标资源解析不了、紧凑
    // 视图索引越界等），通知栏播放器不显示、前台服务建不起来、播放一会被系统回收，而
    // Dart 侧日志里一片干净——songloft-org/songloft#329 前两轮排查就是这么被瞒过去的。补上落日志，
    // 并对平台异常做自愈（摘掉收藏按钮再重播状态）。
    _asyncErrorSub = AudioService.asyncError.listen((error) {
      debugPrint('[AudioService] ⚠️ 原生异步错误（通知/媒体会话可能未建立）: $error');
      if (error is PlatformException) {
        _disableFavoriteControl();
      }
    });

    // 异步初始化 AudioSession（不影响核心功能）
    _initFuture = _initAudioSession();

    debugPrint('[AudioService] SongloftAudioHandler 初始化完成');
  }

  /// 确保初始化完成
  Future<void> ensureInitialized() async {
    await _initFuture;
  }

  /// 初始化 AudioSession（异步，失败安全）
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('[AudioService] AudioSession configured');
      var wasPlayingBeforeInterruption = false;
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (_disposed) return;
        debugPrint(
          '[AudioService] Audio interruption: type=${event.type}, begin=${event.begin}',
        );
        if (event.begin) {
          // 中断开始：记录当前播放状态并暂停
          wasPlayingBeforeInterruption = _player.playing;
          if (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.unknown) {
            _player.pause();
          }
        } else {
          // 中断结束：如果之前正在播放，则恢复
          if (wasPlayingBeforeInterruption) {
            _player.play();
          }
        }
      });
    } catch (e) {
      debugPrint('[AudioService] AudioSession init failed: $e');
    }
  }

  // ★ 核心：将 just_audio PlaybackEvent 转换为 audio_service PlaybackState
  // 官方示例：每个 event 都会触发 playbackState 更新，Android 端据此构建 MediaStyle 通知
  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    final state = _buildPlaybackState();
    // 每个 PlaybackEvent 都会触发，高频；仅 debug 构建输出。
    if (kDebugMode) {
      debugPrint(
        '[AudioService] 🔄 _transformEvent: playing=${state.playing}, '
        'processingState=${state.processingState}, '
        'position=${state.updatePosition.inSeconds}s, '
        'controls=${state.controls.length}个',
      );
    }
    return state;
  }

  // 通知栏「收藏」按钮的图标：**刻意复用桌面小组件的 ic_widget_favorite***，不要另建
  // 一套通知专用图标（songloft-org/songloft#329）：
  //   1. drawable 是**原生资源**，安卓热更只换 libapp.so，`res/` 永远随旧 APK 冻结
  //      （见 docs/cn/flutter_patcher_hotupdate.md）。Dart 侧引用的资源名必须在**所有可能
  //      的宿主 APK** 里都已存在，否则热更后 getIdentifier() 返回 0，原生
  //      PlaybackStateCompat.CustomAction.Builder 直接抛 IllegalArgumentException。
  //   2. 图标由 SystemUI 在**它自己的上下文**里渲染，不能引用应用主题属性
  //      （`?attr/colorControlNormal` → Resources$NotFoundException）。
  // 违反任一条的后果都不是"图标丢了"，而是整条媒体通知不显示 + 前台服务建不起来 →
  // 通知栏播放器看不到、播放一会被系统回收。
  // ic_widget_favorite* 自 fd56c02（小组件那次）起就在 APK 里，且是纯硬编码 fillColor。
  // 改这两个常量前先跑 test/core/audio/notification_icon_contract_test.dart。
  static const MediaControl _favoriteControl = MediaControl(
    androidIcon: 'drawable/ic_widget_favorite',
    label: 'Favorite',
    action: MediaAction.setRating,
    customAction: CustomMediaAction(name: 'toggleFavorite'),
  );

  static const MediaControl _unfavoriteControl = MediaControl(
    androidIcon: 'drawable/ic_widget_favorite_filled',
    label: 'Unfavorite',
    action: MediaAction.setRating,
    customAction: CustomMediaAction(name: 'toggleFavorite'),
  );

  /// 通知栏收藏按钮是否仍然可用。原生侧构建通知抛错（多为宿主 APK 里这张 drawable
  /// 解析不了）时置 false：宁可少一个按钮，也不能让整条通知连着前台服务一起挂掉
  /// （songloft-org/songloft#329）。
  bool _favoriteControlSupported = true;

  /// 摘除通知栏收藏按钮并立刻重播一次状态，让通知/前台服务恢复。
  /// 由 [AudioService.asyncError] 的监听方在原生 setState/setMediaItem 抛错时调用。
  void _disableFavoriteControl() {
    if (!_favoriteControlSupported) return;
    _favoriteControlSupported = false;
    debugPrint(
      '[AudioService] ⚠️ 原生媒体通知构建失败，摘除通知栏收藏按钮后重播状态'
      '（宿主 APK 可能缺少 ic_widget_favorite* 资源，需安装完整安装包）',
    );
    _broadcastState();
  }

  void setFavorited(bool favorited) {
    _isCurrentSongFavorited = favorited;
    _broadcastState();
  }

  /// 依据 `_player` 当前快照构建一份 audio_service [PlaybackState]。
  /// 抽出成独立方法，供 playbackEventStream 转换与 play/pause 等动作后的主动重播共用。
  PlaybackState _buildPlaybackState() {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        if (_favoriteControlSupported)
          _isCurrentSongFavorited ? _unfavoriteControl : _favoriteControl,
        MediaControl.skipToNext,
      ],
      // 显式声明 play/pause/skip 系统动作：Android 13+ 通知与灵动岛/锁屏的媒体控件由系统
      // 依据 MediaSession 的 action 位渲染，除 controls 带入的动作外再补一层，确保上一首/
      // 下一首/播放暂停在系统媒体面板上恒为可用（songloft-org/songloft-player#23）。
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      // 索引是**通知 action 列表**（audio_service 原生侧的 nativeActions）的下标，不是上面
      // controls 的下标：带 customAction 的控件（收藏）会被拿去做 PlaybackState 的
      // CustomAction，**不进**通知 action 列表。故无论收藏按钮在不在，通知 action 恒为
      // [上一首, 播放/暂停, 下一首] 三个，紧凑视图只能取 0/1/2。
      // 写成 [0,1,3] 会让 Android 12 及以下的 SystemUI 渲染紧凑视图时数组越界 →
      // 整条通知不显示（songloft-org/songloft#329）。
      androidCompactActionIndices: const [0, 1, 2],
      processingState:
          const {
            ja.ProcessingState.idle: AudioProcessingState.idle,
            ja.ProcessingState.loading: AudioProcessingState.loading,
            ja.ProcessingState.buffering: AudioProcessingState.buffering,
            ja.ProcessingState.ready: AudioProcessingState.ready,
            ja.ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    );
  }

  /// 立即用当前播放器快照刷新一次 playbackState（供通知栏动作后强制同步系统媒体控件）。
  void _broadcastState() {
    if (_disposed) return;
    playbackState.add(_buildPlaybackState());
  }

  // ====================== audio_service 必需的覆写方法 ======================
  // 官方示例：audio_service Android 端通过调用这些覆写方法来响应通知栏按钮点击

  @override
  Future<void> play() async {
    debugPrint(
      '[AudioService] ▶️ play() 被调用 (before: playing=${_player.playing}, '
      'ps=${_player.processingState})',
    );
    // Web HLS 视频主控模式：just_audio 无音源，转发给 video 元素
    if (hlsVideoPrimaryMode && onPlayHlsVideo != null) {
      onPlayHlsVideo!();
      _broadcastState();
      return;
    }
    // 不要 return/await just_audio 的 play()：其 Future 仅在播放停止时才完成，
    // 若交给 audio_service 的方法通道回调 await，会一直挂起。改为 fire-and-forget，
    // 并立即重播一次 playbackState，让系统媒体控件即时反映播放态
    // （songloft-org/songloft-player#23）。
    unawaited(
      _player.play().catchError((e) {
        debugPrint('[AudioService] play() 失败: $e');
      }),
    );
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    debugPrint(
      '[AudioService] ⏸️ pause() 被调用 (before: playing=${_player.playing}, '
      'ps=${_player.processingState})',
    );
    // Web HLS 视频主控模式：转发给 video 元素
    if (hlsVideoPrimaryMode && onPauseHlsVideo != null) {
      onPauseHlsVideo!();
      _broadcastState();
      return;
    }
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioService] pause() 失败: $e');
    }
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    debugPrint('[AudioService] ⏹️ stop() 被调用');
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    debugPrint('[AudioService] ⏩ seek() 被调用: ${position.inSeconds}s');
    // Web HLS 视频主控模式：just_audio 无音源，seek 必须落在 video 元素上，
    // 否则恢复播放进度 / 媒体会话 seek 会静默失效。
    if (hlsVideoPrimaryMode && onSeekHlsVideo != null) {
      onSeekHlsVideo!(position);
      return Future.value();
    }
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    // 记录回调是否已注入：后台被系统唤醒但 PlayerNotifier 未重建时 onSkipToNext 可能为 null，
    // 此日志可在真机 logcat 里一刀切分「按钮没到 Dart」还是「到了但无回调」
    // （songloft-org/songloft-player#23）。
    debugPrint(
      '[AudioService] ⏭️ skipToNext() 被调用 (callback=${onSkipToNext != null})',
    );
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint(
      '[AudioService] ⏮️ skipToPrevious() 被调用 (callback=${onSkipToPrevious != null})',
    );
    onSkipToPrevious?.call();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    debugPrint('[AudioService] customAction: $name');
    if (name == 'toggleFavorite') {
      onToggleFavorite?.call();
    }
  }

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    debugPrint('[AudioService] setRating 被调用 (favorite toggle)');
    onToggleFavorite?.call();
  }

  // ====================== Android Auto 媒体浏览 ======================

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final dataSource = mediaBrowseDataSource;
    if (dataSource == null) return [];

    try {
      switch (parentMediaId) {
        case 'root':
          return [
            _buildBrowsableItem('recent_plays', '最近播放'),
            _buildBrowsableItem('favorites', '我的收藏'),
            _buildBrowsableItem('playlists', '歌单'),
            _buildBrowsableItem('all_songs', '所有歌曲'),
          ];
        case 'recent':
        case 'recent_plays':
          final songs = await dataSource.getRecentSongs();
          return songs.map(_songToMediaItem).toList();
        case 'favorites':
          final songs = await dataSource.getFavoriteSongs();
          return songs.map(_songToMediaItem).toList();
        case 'playlists':
          final playlists = await dataSource.getPlaylists();
          return playlists.map(_playlistToMediaItem).toList();
        case 'all_songs':
          final songs = await dataSource.getAllSongs();
          return songs.map(_songToMediaItem).toList();
        default:
          if (parentMediaId.startsWith('playlist_')) {
            final id = int.tryParse(parentMediaId.substring(9));
            if (id != null) {
              final songs = await dataSource.getPlaylistSongs(id);
              return songs.map(_songToMediaItem).toList();
            }
          }
          return [];
      }
    } catch (e) {
      debugPrint('[AudioService] getChildren($parentMediaId) error: $e');
      return [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final dataSource = mediaBrowseDataSource;
    if (dataSource == null) return null;

    try {
      final id = int.tryParse(mediaId.replaceFirst(RegExp(r'^song_'), ''));
      if (id == null) return null;
      final song = await dataSource.getSongById(id);
      if (song == null) return null;
      return _songToMediaItem(song);
    } catch (e) {
      debugPrint('[AudioService] getMediaItem($mediaId) error: $e');
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final dataSource = mediaBrowseDataSource;
    if (dataSource == null) return [];

    try {
      final songs = await dataSource.searchSongs(query);
      return songs.map(_songToMediaItem).toList();
    } catch (e) {
      debugPrint('[AudioService] search($query) error: $e');
      return [];
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final dataSource = mediaBrowseDataSource;
    if (dataSource == null || onPlayFromBrowse == null) return;

    try {
      final id = int.tryParse(mediaId.replaceFirst(RegExp(r'^song_'), ''));
      if (id == null) return;
      final song = await dataSource.getSongById(id);
      if (song == null) return;
      await onPlayFromBrowse!.call(song);
    } catch (e) {
      debugPrint('[AudioService] playFromMediaId($mediaId) error: $e');
    }
  }

  MediaItem _songToMediaItem(Song song) {
    Uri? artUri;
    final coverUrl = song.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      artUri = Uri.parse(
        UrlHelper.buildCoverUrl(coverUrl, width: _artUriWidth),
      );
    }

    return MediaItem(
      id: 'song_${song.id}',
      title: song.title,
      artist: song.artist ?? '',
      album: song.album ?? '',
      artUri: artUri,
      duration: Duration(milliseconds: (song.duration * 1000).toInt()),
      playable: true,
    );
  }

  MediaItem _buildBrowsableItem(String id, String title) {
    return MediaItem(id: id, title: title, playable: false);
  }

  MediaItem _playlistToMediaItem(Playlist playlist) {
    Uri? artUri;
    final coverUrl = playlist.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      artUri = Uri.parse(
        UrlHelper.buildCoverUrl(coverUrl, width: _artUriWidth),
      );
    }

    return MediaItem(
      id: 'playlist_${playlist.id}',
      title: playlist.name,
      artist: '${playlist.songCount} 首歌曲',
      artUri: artUri,
      playable: false,
    );
  }

  // ====================== 业务方法 ======================

  /// 播放歌曲
  /// 所有 type(local/remote/radio)统一使用 song.url —— 后端 marshal Song 时
  /// 自动把 url 填成 /api/v1/songs/{id}/play,按 type 分发到 ServeFile / Orchestrator /
  /// 直链下载 / 电台 302,客户端无需关心 type。
  /// URL 拼接（baseUrl + access_token）统一走 UrlHelper。
  /// [audioTrack] 仅 Web 使用：抽取指定音频流播放（audio-relative index，
  /// songloft-org/songloft#298）。缺省时对 Web 多音轨容器（mka）自动取首轨(0)，
  /// 使默认播放与切换统一走 `?track=` 机制（AAC 无损 remux 成 m4a）。原生端忽略此参数
  /// （由 libmpv 直接切轨）。
  Future<void> playSong(
    Song song, {
    String? quality,
    int? audioTrack,
    bool normalize = false,
  }) async {
    // 确保 stream listeners 已建立
    await _initFuture;

    debugPrint(
      '[Player] SongloftAudioHandler.playSong: ${song.title} (type: ${song.type})',
    );
    try {
      ja.AudioSource source;

      if (song.url == null || song.url!.isEmpty) {
        debugPrint('[Player] SongloftAudioHandler: no valid source for song');
        throw Exception('无法播放：歌曲没有有效的播放源');
      }

      // 桌面原生端播放 HLS 电台时请求后端直连源站、绕过反代：桌面 player(libmpv)自带
      // HLS 解析、无 CORS 限制，且下方 _buildLiveStreamHeaders 已为桌面附带 Referer/UA
      // 应对防盗链；直连避免直播切片经反代往返后过期 404（songloft-org/songloft#249）。
      // 移动端不带此参数（其原生 player 不发 Referer/UA，保留反代以兼容防盗链源）。
      final isDesktopLive =
          !kIsWeb &&
          song.isLive &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS);

      // Web 多音轨容器（mka）：默认播放与切换统一走后端 ?track= 抽轨（首轨=0），
      // 抽出的 AAC 无损 remux 成 m4a、Web 原生可播；避免「默认走 mp3、切换走 m4a」的格式割裂。
      // 原生端 audioTrack 恒为 null（由 libmpv 直接切轨），effectiveTrack 保持 null。
      final effectiveTrack =
          kIsWeb && !song.isVideo
              ? (audioTrack ??
                  (AudioFormatHelper.isWebMultiTrackContainer(song.format)
                      ? 0
                      : null))
              : null;

      // 原生平台无法携带 Authorization Header,UrlHelper 会自动拼接 baseUrl + access_token。
      // 视频歌曲三路分支：
      // - Web 非浏览器兼容格式：走后端 HLS 转码端点，URL 以 .m3u8 结尾，
      //   songloft_web_audio_player 自动用 hls.js 处理。
      // - 原生端本地歌曲命中老旧容器黑名单（mpg/rmvb/wmv 等）：也走 video-hls——
      //   这类容器无索引（mpv 在 HTTP 上二分 seek 产生大量超大 range 请求）且
      //   MPEG-2/RV/VC-1 等老编码手机无硬解、软解卡顿。
      //   附加 media=video 供 SongloftMediaKitPlayer 判定视频源创建纹理。
      //   Bundle 本地模式除外：内嵌后端无 ffmpeg 会 503，且回环直出无网络 seek 开销。
      // - 其余：buildVideoUrl（media=video）后端直出原容器，保留画面供 media_kit 渲染，
      //   不做平台音频转码（转码 -vn 会丢画面）。
      final String songUrl;
      if (song.isVideo) {
        if (kIsWeb &&
            !AudioFormatHelper.isWebCompatibleVideo(
              song.format,
              song.filePath,
            )) {
          songUrl = UrlHelper.buildVideoHlsUrl(song.id);
        } else if (!kIsWeb &&
            song.type == AppConstants.songTypeLocal &&
            !song.isLive &&
            !_isLocalEmbeddedBackend &&
            AudioFormatHelper.needsNativeVideoHls(song.format, song.filePath)) {
          songUrl = UrlHelper.buildVideoHlsUrl(song.id, mediaVideoFlag: true);
        } else {
          songUrl = UrlHelper.buildVideoUrl(song.url!);
        }
      } else {
        songUrl = UrlHelper.buildSongUrl(
          song.url!,
          songFormat: song.format,
          quality: quality,
          hlsDirect: isDesktopLive,
          audioTrack: effectiveTrack,
          normalize: normalize,
        );
      }

      debugPrint('[Player] SongloftAudioHandler: song url: $songUrl');
      final liveHeaders = _buildLiveStreamHeaders(song);

      // Web HLS 视频主控模式：video 元素接管音视频播放，不加载 just_audio。
      // 单 video 元素同时处理音频和画面，避免双元素同步问题和 idle 状态问题。
      if (kIsWeb &&
          song.isVideo &&
          !AudioFormatHelper.isWebCompatibleVideo(song.format, song.filePath)) {
        // 先 stop 释放之前的 audio 源（如果有）
        await _player.stop();
        hlsVideoPrimaryMode = true;
        hlsVideoUrl = songUrl;
        _updateNowPlaying(song);
        // 通知后端当前歌曲激活
        try {
          notifySongActivated?.call(song.id);
        } catch (e) {
          debugPrint('[Player] notifySongActivated error (ignored): $e');
        }
        // 启动 video 元素播放（立即创建 DOM 元素 + hls.js，无需等 widget 挂载）
        onStartHlsVideo?.call(songUrl);
        debugPrint(
          '[Player] SongloftAudioHandler: HLS video primary mode, skipping just_audio',
        );
        return;
      }

      // 非 HLS 视频路径：清除 HLS video primary 标志
      hlsVideoPrimaryMode = false;
      hlsVideoUrl = null;
      onStopHlsVideo?.call();

      // 客户端本地缓存优先（songloft-org/songloft#312）：用户手动缓存过的歌直接播
      // 本机文件，离线可播、零流量。直播/Web 不缓存（resolvePlayablePath 内部 kIsWeb
      // 返回 null）。命中即用 file:// 源，绕过下方远端流串/边播边缓存分支。
      await SongCacheService().load();
      final cachedPath = await SongCacheService().resolvePlayablePath(song.id);
      lastPlaybackSource =
          cachedPath != null
              ? PlaybackSource.localCache
              : PlaybackSource.remoteStream;

      // Web 平台 / 电台直播流使用 AudioSource.uri（直播流无法缓存）。
      // Windows 也走 AudioSource.uri：LockCachingAudioSource 会把远端音频缓存到
      // %TEMP%\just_audio_cache 再 renameSync，而 Windows 下打开的文件句柄会阻止
      // rename（POSIX 不会），重播/重试同一 URL 时抛 errno 32「另一个程序正在使用此文件」
      // 导致播放失败并陷入无限重试（songloft-org/songloft#271）。desktop 由 libmpv
      // 直接支持网络流 seek，且后端 cache_service 已提供透明缓存，客户端缓存纯属冗余。
      // 其他平台（Android/iOS/Linux/macOS）普通歌曲仍用 LockCachingAudioSource 边播边缓存。
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      // 视频文件通常较大，同样走 AudioSource.uri：libmpv/原生后端直接支持网络流 seek，
      // 后端已有透明缓存；避免 LockCachingAudioSource 代理大文件 seek 的性能/句柄问题。
      final useLiveSource = kIsWeb || song.isLive || isWindows || song.isVideo;
      if (cachedPath != null) {
        debugPrint(
          '[Player] SongloftAudioHandler: play from local cache: $cachedPath',
        );
        source = ja.AudioSource.uri(Uri.file(cachedPath));
        _normCacheFile = null;
      } else if (useLiveSource) {
        final isMobile =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);
        final isHls = songUrl.toLowerCase().contains('.m3u8');

        if (AppConfig.insecureTls && isHls && (isMobile || song.isVideo)) {
          // 移动端 HLS 电台 / 各端 HLS 视频连自签服务器：just_audio 自带代理只按单一 URL
          // 注册 handler，无法处理 m3u8 里指向别的 path 的切片（相对 URL 触发空指针、绝对
          // URL 直连自签源站），故改走自研 HLS-aware trust-all 本地代理：拉取 m3u8 →
          // 递归改写所有子资源经本机代理 → 全程 trust-all（songloft-org/songloft#272）。
          // 桌面端音频直播不走此分支（保留 #249 的 hlsDirect 直连源站逻辑，避免回归）。
          var proxied = await InsecureMediaProxy.instance.wrapHls(songUrl);
          // wrapHls 的入口 URL 只保留 path（query 丢失），视频源需补回 media=video
          // 供 SongloftMediaKitPlayer 判定创建视频纹理，否则黑屏只出声。
          if (song.isVideo) {
            proxied = UrlHelper.appendMediaVideoParam(proxied);
          }
          source = ja.AudioSource.uri(Uri.parse(proxied));
        } else {
          // 「忽略 SSL 证书校验」开启时，AudioSource.uri 直连路径（视频 / Windows 普通歌曲 /
          // 非 HLS 直播 / 桌面直播）会把 URL 直接交给原生播放器（libmpv / ExoPlayer /
          // AVPlayer），其 TLS 握手在 dart:io 之外，不受 HttpOverrides 的 trust-all 影响，
          // 导致自签证书服务器上「能登录、不能播放」（songloft-org/songloft#272）。此处强制
          // 附带一个非空 header，触发 just_audio 启用本地明文回环代理（127.0.0.1）：原生
          // 播放器只连本机 http，真正的上游 HTTPS 改由 just_audio 内部的 Dart HttpClient
          // 拉取——后者继承 HttpOverrides.global 的 trust-all，从而让 SSL 忽略覆盖到播放路径。
          // （HLS 由上面的自研代理处理，此处的单资源代理对切片无能为力。）
          // 关闭该开关时行为不变（不多一跳代理）。web 不走原生代理，浏览器自行处理 TLS。
          final headers =
              (!kIsWeb && AppConfig.insecureTls)
                  ? <String, String>{'Accept': '*/*', ...?liveHeaders}
                  : liveHeaders;
          source = ja.AudioSource.uri(Uri.parse(songUrl), headers: headers);
        }
        _normCacheFile = null;
      } else {
        // 普通歌曲用 LockCachingAudioSource（本身即经本地代理 + Dart HttpClient 边播边缓存），
        // 上游 HTTPS 已受 HttpOverrides trust-all 覆盖，无需额外处理。
        if (normalize) {
          // normalize 流可能是 chunked（均衡产物未就绪时边转边发），用显式 cacheFile
          // 以便切歌时检测并清理不完整数据（songloft-org/songloft-player#35）。
          final dir = await getTemporaryDirectory();
          final normDir = Directory('${dir.path}/songloft_norm_cache');
          if (!normDir.existsSync()) normDir.createSync(recursive: true);
          final cacheFile = File('${normDir.path}/${song.id}.audio');
          if (cacheFile.existsSync()) {
            // 完整缓存命中（LockCachingAudioSource 已将 .part rename 为最终文件）
            source = ja.AudioSource.uri(Uri.file(cacheFile.path));
            _normCacheFile = null;
          } else {
            _cleanupPartialNormDownload(cacheFile.path);
            _normCacheFile = cacheFile;
            source = ja.LockCachingAudioSource(
              Uri.parse(songUrl),
              cacheFile: _normCacheFile!,
            );
          }
        } else {
          _normCacheFile = null;
          source = ja.LockCachingAudioSource(Uri.parse(songUrl));
        }
      }

      // ★ 修复自动切歌时通知栏不更新问题：
      // 先更新 mediaItem，再 setAudioSource，再 play()。
      // 原来的顺序是 setAudioSource → _updateNowPlaying → play()，
      // 但在自动切歌场景下，setAudioSource 会触发 processingState 从 completed → idle，
      // audio_service 在 idle+playing=false 时可能停止前台 Service，
      // 导致之后的 mediaItem.add() 无法刷新到通知栏。
      // 提前更新 mediaItem，确保通知栏在 Service 重建时能读取到正确的元数据。
      _updateNowPlaying(song);

      // 所有平台（含 Web）均不调用 stop()，setAudioSource() 会自动替换当前源。
      // Web: stop() 会 removeAttribute('src') 重置 <audio> 元素，破坏浏览器的
      // autoplay 授权链——后台标签页中自动切歌时 play() 被拒绝导致无声（#351）。
      // iOS: stop() 会使音频会话变为空闲，系统限制后台网络访问，下一首无法加载。
      // vendored Web player 的完整 load() 会重建音源树缓存并处理 HLS 清理，无需预先 stop
      // （songloft-org/songloft#376）。

      // 主动通知后端：本会话已切到 song.id，让其他 songID 的 prefetch/transcode/reassign 退场。
      // 必须在 setAudioSource 之前发起，让后端 plugin worker 尽早释放给本次播放使用。
      // 本地缓存播放（可能离线、且不占用后端流串 worker）无需通知，跳过。
      if (lastPlaybackSource != PlaybackSource.localCache) {
        try {
          notifySongActivated?.call(song.id);
        } catch (e) {
          debugPrint('[Player] notifySongActivated error (ignored): $e');
        }
      }

      debugPrint('[Player] SongloftAudioHandler: setting audio source');
      await _setAudioSourceWithGuard(source, song);

      debugPrint('[Player] SongloftAudioHandler: starting playback');
      // 注意：just_audio 的 play() Future 在播放停止时才完成，不能 await，否则会阻塞调用链
      // 使用 fire-and-forget 模式，播放状态通过 playbackEventStream.pipe() 自动同步
      unawaited(
        _player.play().catchError((e) {
          debugPrint('[Player] SongloftAudioHandler: play() failed: $e');
        }),
      );
      debugPrint(
        '[Player] SongloftAudioHandler: playback triggered (non-blocking)',
      );
      // 不再需要手动调用 _broadcastState()，pipe() 会自动同步
    } catch (e) {
      debugPrint('[Player] SongloftAudioHandler.playSong error: $e');
      rethrow;
    }
  }

  /// Web 端切换音轨（原唱/伴奏，songloft-org/songloft#298）。
  ///
  /// 浏览器无多音轨枚举/切换 API，故通过重建播放 URL（`?track=N`）+ [ja.AudioPlayer.setAudioSource]
  /// 的 `initialPosition` 无缝重载：抽出的音轨（AAC 无损 remux 成 m4a）在切换前的进度处继续，
  /// 并恢复切换前的播放/暂停状态（短暂缓冲可接受）。仅 Web 调用；歌曲元数据不变，无需刷新通知栏。
  Future<void> switchWebAudioTrack(
    Song song, {
    required int trackIndex,
    required Duration position,
    required bool resumePlaying,
    String? quality,
  }) async {
    await _initFuture;
    if (song.url == null || song.url!.isEmpty) return;
    final url = UrlHelper.buildSongUrl(
      song.url!,
      songFormat: song.format,
      quality: quality,
      audioTrack: trackIndex,
    );
    debugPrint('[Player] switchWebAudioTrack: track=$trackIndex url=$url');
    final source = ja.AudioSource.uri(Uri.parse(url));
    await _player.setAudioSource(source, initialPosition: position);
    if (resumePlaying) {
      unawaited(
        _player.play().catchError((e) {
          debugPrint('[Player] switchWebAudioTrack: play() failed: $e');
        }),
      );
    }
  }

  Future<void> _setAudioSourceWithGuard(
    ja.AudioSource source,
    Song song,
  ) async {
    if (!song.isLive) {
      await _player.setAudioSource(source);
      return;
    }

    try {
      await _player
          .setAudioSource(source)
          .timeout(
            _liveLoadTimeout,
            onTimeout: () async {
              debugPrint(
                '[Player] live stream load timed out after ${_liveLoadTimeout.inSeconds}s: ${song.title}',
              );
              await _player.stop();
              throw TimeoutException('直播流加载超时');
            },
          );
    } catch (_) {
      try {
        await _player.stop();
      } catch (stopError) {
        debugPrint('[Player] stop after live load failure ignored: $stopError');
      }
      rethrow;
    }
  }

  Map<String, String>? _buildLiveStreamHeaders(Song song) {
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (kIsWeb || !song.isLive || !isDesktop) return null;

    final headers = <String, String>{
      'User-Agent': _streamUserAgent,
      'Accept': '*/*',
      'Icy-MetaData': '1',
    };

    final sourceUrl = song.sourceUrl;
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(sourceUrl);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        final port = uri.hasPort ? ':${uri.port}' : '';
        headers['Referer'] = '${uri.scheme}://${uri.host}$port/';
      }
    }

    return headers;
  }

  /// 更新通知栏元数据
  void _updateNowPlaying(Song song) {
    _originalTitle = song.title;
    _originalArtist = song.artist ?? '未知艺术家';

    // artUri 由 Android 系统直接拉取，必须是带 baseUrl + access_token 的完整 URL。
    // 传 ?w= 缩略，避免系统每首歌拉全尺寸封面加剧 NAS 拥堵（songloft-org/songloft-player#39）。
    Uri? artUri;
    final coverUrl = song.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      artUri = Uri.parse(
        UrlHelper.buildCoverUrl(coverUrl, width: _artUriWidth),
      );
    }

    final item = MediaItem(
      id: '${song.type}_${song.id}',
      title: song.title,
      artist: _originalArtist!,
      album: song.album ?? '',
      artUri: artUri,
      duration: Duration(milliseconds: (song.duration * 1000).toInt()),
    );

    // 详细日志输出 MediaItem 的所有字段，便于确认数据正确性
    debugPrint('[AudioService] _updateNowPlaying MediaItem:');
    debugPrint('  id: ${item.id}');
    debugPrint('  title: ${item.title}');
    debugPrint('  artist: ${item.artist}');
    debugPrint('  album: ${item.album}');
    debugPrint('  artUri: ${item.artUri}');
    debugPrint('  duration: ${item.duration}');

    mediaItem.add(item);
    debugPrint('[AudioService] MediaItem added to stream');
  }

  /// 用当前歌词行更新 Now Playing 元数据。
  /// [inTitle] 为 true（默认）：标题=歌词行，副标题="歌名 - 艺术家"；
  /// 为 false：标题=歌名，副标题=纯歌词行。
  void updateNowPlayingLyric(String lyricLine, {bool inTitle = true}) {
    final current = mediaItem.value;
    if (current == null || _originalTitle == null) return;

    if (lyricLine.isEmpty) {
      restoreNowPlaying();
      return;
    }

    if (inTitle) {
      final artist =
          _originalArtist?.isNotEmpty == true
              ? '$_originalTitle - $_originalArtist'
              : _originalTitle!;
      mediaItem.add(current.copyWith(title: lyricLine, artist: artist));
    } else {
      // 歌名放标题，副标题显示纯歌词行
      mediaItem.add(
        current.copyWith(title: _originalTitle!, artist: lyricLine),
      );
    }
  }

  /// 恢复 Now Playing 元数据为原始歌曲信息
  void restoreNowPlaying() {
    final current = mediaItem.value;
    if (current == null || _originalTitle == null) return;
    mediaItem.add(
      current.copyWith(title: _originalTitle!, artist: _originalArtist),
    );
  }

  /// 更新通知栏元数据的 duration（当获取到实际时长时调用）
  void updateDuration(Duration duration) {
    final current = mediaItem.value;
    if (current != null) {
      mediaItem.add(current.copyWith(duration: duration));
    }
  }

  // _broadcastState 方法已移除，改用官方示例的 pipe() 模式自动同步

  // ====================== 暴露 just_audio 的 streams（保持与现有代码兼容）======================

  /// 播放位置流
  Stream<Duration> get positionStream => _player.positionStream;

  /// 总时长流
  Stream<Duration?> get durationStream => _player.durationStream;

  /// 播放状态流
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  /// 是否正在播放流
  Stream<bool> get playingStream => _player.playingStream;

  /// 缓冲位置流
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// 获取处理状态流（用于检测歌曲结束）
  Stream<ja.ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// 当前是否正在播放
  bool get isPlaying => _player.playing;

  /// 当前播放位置
  Duration get position => _player.position;

  /// 当前总时长
  Duration? get duration => _player.duration;

  /// 当前音量
  double get volume => _player.volume;

  /// 当前处理状态
  ja.ProcessingState get processingState => _player.processingState;

  // ====================== normalize 缓存管理 ======================

  /// 切歌时清理不完整的 normalize 缓存（songloft-org/songloft-player#35）。
  ///
  /// 判定依据：LockCachingAudioSource 下载完成时将 .part rename 为最终 cacheFile，
  /// 因此 cacheFile 存在即表示下载完整——保留；不存在则说明下载未完成（数据仍在
  /// .part 中），清理 .part 及 .mime 残留文件。
  void clearIncompleteNormCache() {
    if (_normCacheFile == null) return;
    if (_normCacheFile!.existsSync()) {
      debugPrint(
        '[Player] norm cache complete, keeping: ${_normCacheFile!.path}',
      );
      _normCacheFile = null;
      return;
    }
    debugPrint(
      '[Player] norm cache incomplete, cleaning up: ${_normCacheFile!.path}',
    );
    _cleanupPartialNormDownload(_normCacheFile!.path);
    _normCacheFile = null;
  }

  /// 删除 LockCachingAudioSource 的 .part（下载中间态）和 .mime（内容类型记录）文件。
  void _cleanupPartialNormDownload(String cachePath) {
    for (final suffix in ['.part', '.mime']) {
      try {
        final f = File('$cachePath$suffix');
        if (f.existsSync()) {
          f.deleteSync();
          debugPrint('[Player] deleted partial norm file: $cachePath$suffix');
        }
      } catch (e) {
        debugPrint('[Player] norm cleanup failed (ignored): $e');
      }
    }
  }

  // ====================== 音量控制 ======================

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  /// 设置播放速度 (0.5 - 2.0)
  @override
  Future<void> setSpeed(double speed) =>
      _player.setSpeed(speed.clamp(0.5, 2.0));

  // ====================== 资源释放 ======================

  /// 释放资源
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    debugPrint('[AudioService] dispose 开始');
    await _interruptionSub?.cancel();
    debugPrint('[AudioService] interruption subscription canceled');
    await _processingStateSub.cancel();
    debugPrint('[AudioService] processingState subscription canceled');
    await _playingStateSub.cancel();
    debugPrint('[AudioService] playing state subscription canceled');
    await _playbackLogSub.cancel();
    debugPrint('[AudioService] playback log subscription canceled');
    await _asyncErrorSub.cancel();
    debugPrint('[AudioService] async error subscription canceled');
    await _playbackEventSub.cancel();
    debugPrint('[AudioService] playback event subscription canceled');
    await _player.dispose();
    debugPrint('[AudioService] player disposed');
  }
}
