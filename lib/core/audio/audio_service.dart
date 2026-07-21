import 'dart:async';

// LockCachingAudioSource 是 just_audio 中标记为实验性的边播边缓存 API，
// 目前没有稳定替代方案，此处有意使用以提升播放体验。
// ignore_for_file: experimental_member_use

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../config/app_config.dart';
import '../../features/playlist/domain/playlist.dart';
import '../network/insecure_media_proxy.dart';
import '../../shared/models/song.dart';
import '../utils/audio_format_helper.dart';
import '../utils/url_helper.dart';
import 'media_browse_data_source.dart';

/// Songloft 音频处理器 - 集成 audio_service 实现通知栏控制
class SongloftAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Duration _liveLoadTimeout = Duration(seconds: 18);
  static const String _streamUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 Songloft/1.0';

  // 所有原生平台统一 media_kit(libmpv) 后端，EQ 走 mpv `af`（见 MpvEqualizerService），
  // 不再使用 just_audio 的 AndroidEqualizer / AudioPipeline androidAudioEffects——后者会让
  // just_audio 对平台 player 调 androidEqualizerGetParameters()，而 media_kit 的
  // SongloftMediaKitPlayer 不实现该 Android 专属方法，会致全曲无法播放（songloft-org/songloft#76）。
  late final ja.AudioPlayer _player = ja.AudioPlayer();

  String? _originalTitle;
  String? _originalArtist;

  /// 通知栏回调（由 PlayerNotifier 设置）
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  VoidCallback? onSongCompleted;

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
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _disposed = false;

  SongloftAudioHandler() {
    // 使用 listen + add 而非 pipe()：pipe() 内部调用 addStream 独占 sink，
    // 导致 super.stop() 等方法无法再调用 playbackState.add()，
    // 退出时抛出 "You cannot add items while items are being added from addStream"。
    _playbackEventSub = _player.playbackEventStream
        .map(_transformEvent)
        .listen(playbackState.add);
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
    final state = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop,
      },
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

  // ====================== audio_service 必需的覆写方法 ======================
  // 官方示例：audio_service Android 端通过调用这些覆写方法来响应通知栏按钮点击

  @override
  Future<void> play() {
    debugPrint('[AudioService] ▶️ play() 被调用');
    return _player.play();
  }

  @override
  Future<void> pause() {
    debugPrint('[AudioService] ⏸️ pause() 被调用');
    return _player.pause();
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
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[AudioService] ⏭️ skipToNext() 被调用');
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[AudioService] ⏮️ skipToPrevious() 被调用');
    onSkipToPrevious?.call();
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
      artUri = Uri.parse(UrlHelper.buildCoverUrl(coverUrl));
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
      artUri = Uri.parse(UrlHelper.buildCoverUrl(coverUrl));
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
  Future<void> playSong(Song song, {String? quality, int? audioTrack}) async {
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
      final effectiveTrack = kIsWeb && !song.isVideo
          ? (audioTrack ??
              (AudioFormatHelper.isWebMultiTrackContainer(song.format)
                  ? 0
                  : null))
          : null;

      // 原生平台无法携带 Authorization Header,UrlHelper 会自动拼接 baseUrl + access_token。
      // 视频歌曲用 buildVideoUrl（media=video）：后端直出原容器，保留画面供 media_kit 渲染，
      // 不做平台音频转码（转码 -vn 会丢画面）。
      final songUrl = song.isVideo
          ? UrlHelper.buildVideoUrl(song.url!)
          : UrlHelper.buildSongUrl(
              song.url!,
              songFormat: song.format,
              quality: quality,
              hlsDirect: isDesktopLive,
              audioTrack: effectiveTrack,
            );

      debugPrint('[Player] SongloftAudioHandler: song url: $songUrl');
      final liveHeaders = _buildLiveStreamHeaders(song);

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
      if (useLiveSource) {
        final isMobile =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);
        final isHls = songUrl.toLowerCase().contains('.m3u8');

        if (AppConfig.insecureTls && isMobile && isHls) {
          // 移动端 HLS 电台连自签服务器：just_audio 自带代理只按单一 URL 注册 handler，
          // 无法处理 m3u8 里指向别的 path 的切片（相对 URL 触发空指针、绝对 URL 直连自签
          // 源站），故改走自研 HLS-aware trust-all 本地代理：拉取 m3u8 → 递归改写所有子
          // 资源经本机代理 → 全程 trust-all（songloft-org/songloft#272）。桌面端直播不走此
          // 分支（保留 #249 的 hlsDirect 直连源站逻辑，避免回归）。
          final proxied = await InsecureMediaProxy.instance.wrapHls(songUrl);
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
      } else {
        // 普通歌曲用 LockCachingAudioSource（本身即经本地代理 + Dart HttpClient 边播边缓存），
        // 上游 HTTPS 已受 HttpOverrides trust-all 覆盖，无需额外处理。
        source = ja.LockCachingAudioSource(Uri.parse(songUrl));
      }

      // ★ 修复自动切歌时通知栏不更新问题：
      // 先更新 mediaItem，再 setAudioSource，再 play()。
      // 原来的顺序是 setAudioSource → _updateNowPlaying → play()，
      // 但在自动切歌场景下，setAudioSource 会触发 processingState 从 completed → idle，
      // audio_service 在 idle+playing=false 时可能停止前台 Service，
      // 导致之后的 mediaItem.add() 无法刷新到通知栏。
      // 提前更新 mediaItem，确保通知栏在 Service 重建时能读取到正确的元数据。
      _updateNowPlaying(song);

      // Web 平台需要 stop() 释放 HTML5 Audio 元素；
      // 原生平台不调用 stop()，setAudioSource() 会自动替换当前源。
      // 在 iOS 后台场景下，stop() 会使音频会话变为空闲，
      // 导致系统限制后台网络访问，使下一首歌曲无法加载。
      if (kIsWeb) {
        await _player.stop();
      }

      // 主动通知后端：本会话已切到 song.id，让其他 songID 的 prefetch/transcode/reassign 退场。
      // 必须在 setAudioSource 之前发起，让后端 plugin worker 尽早释放给本次播放使用。
      try {
        notifySongActivated?.call(song.id);
      } catch (e) {
        debugPrint('[Player] notifySongActivated error (ignored): $e');
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

    // artUri 由 Android 系统直接拉取，必须是带 baseUrl + access_token 的完整 URL
    Uri? artUri;
    final coverUrl = song.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      artUri = Uri.parse(UrlHelper.buildCoverUrl(coverUrl));
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
      mediaItem.add(current.copyWith(title: _originalTitle!, artist: lyricLine));
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

  // ====================== 音量控制 ======================

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

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
    await _playbackLogSub.cancel();
    debugPrint('[AudioService] playback log subscription canceled');
    await _playbackEventSub.cancel();
    debugPrint('[AudioService] playback event subscription canceled');
    await _player.dispose();
    debugPrint('[AudioService] player disposed');
  }
}
