import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:volume_controller/volume_controller.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/audio/media_browse_data_source.dart';
import '../../../../core/platform/live_activity_service.dart';
import '../../../../core/platform/home_widget_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/storage/preference_sync_service.dart';
import '../../../../core/utils/audio_format_helper.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/playback_state_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/l10n_holder.dart';
import '../../../../main.dart';
import '../../../../shared/models/song.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'web_video_playback_provider.dart';
import '../../../library/data/songs_api.dart';
import '../../../library/presentation/providers/category_provider.dart'
    show categoryFields, categorySongsFilter;
import '../../../library/presentation/providers/favorite_provider.dart';
import '../../../library/presentation/providers/songs_provider.dart';
import '../../../playlist/data/playlist_api.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';
import '../../domain/playback_context.dart';
import '../../domain/player_state.dart';
import '../../domain/use_cases/play_mode_resolver.dart';
import '../../domain/use_cases/play_queue.dart';
import '../../domain/use_cases/playback_resume_state.dart';
import '../../domain/use_cases/queue_loader.dart';
import '../../domain/use_cases/sleep_timer_logic.dart';
import '../../domain/use_cases/playback_retry_policy.dart';
import '../../domain/use_cases/prefetch_strategy.dart';
import '../../domain/use_cases/song_completion_router.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import 'lyric_provider.dart';

/// 播放器状态 Provider
final playerStateProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// 播放器状态管理 Notifier
class PlayerNotifier extends Notifier<PlayerState> {
  late SongloftAudioHandler _audioHandler;
  late SecureStorageService _secureStorage;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;
  StreamSubscription<double>? _systemVolumeSubscription;

  final SleepTimerLogic _sleepTimerLogic = SleepTimerLogic();
  CancelToken? _prefetchCancelToken;
  bool _disposed = false; // Notifier 是否已销毁（微任务回调前的安全守卫）

  final Random _random = Random();
  late final PlayModeResolver _modeResolver;
  int _loadGeneration = 0; // 后台加载代次，用于取消过期的异步加载任务
  final QueueLoader _queueLoader = QueueLoader();
  int _playGeneration = 0; // 播放协程代次：用户快速切歌时，旧协程在 await 后发现 gen 变化即退出
  int _playGenerationAtSource = 0; // 当前音频源对应的代次，position stream 据此忽略切歌过渡期的旧位置

  // 播放失败重试 & 歌曲完成路由（domain use-cases）
  final PlaybackRetryPolicy _retryPolicy = PlaybackRetryPolicy();
  final SongCompletionRouter _completionRouter = SongCompletionRouter();
  final PrefetchStrategy _prefetchStrategy = PrefetchStrategy();

  int get _consecutiveFailures => _retryPolicy.consecutiveFailures;
  Song? _lastPlayedSong;

  // 播放状态持久化
  Timer? _saveDebounceTimer;
  Timer? _positionSaveTimer;
  static const int _saveDebounceMs = 2000;
  static const int _positionSaveIntervalSec = 10;
  final PlaybackStateStorage _playbackStorage = PlaybackStateStorage();
  final PlaybackResumeState _playbackResumeState = PlaybackResumeState();
  bool _webPlaybackPersistenceDisabled = false;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(audioHandlerProvider);
    _secureStorage = ref.watch(secureStorageProvider);
    _modeResolver = PlayModeResolver(mode: PlayMode.order);

    // 设置通知栏回调
    _audioHandler.onSkipToNext = () => playNext();
    _audioHandler.onSkipToPrevious = () => playPrev();
    _audioHandler.onSongCompleted = _onSongCompleted;
    _audioHandler.onToggleFavorite = _toggleFavoriteFromNotification;

    // Web HLS 视频回调：playSong 中触发 → 直接创建 video DOM 元素开始播放
    if (kIsWeb) {
      _audioHandler.onStartHlsVideo = (url) {
        ref.read(webVideoPlaybackProvider.notifier).startPlayback(url);
      };
      _audioHandler.onStopHlsVideo = () {
        ref.read(webVideoPlaybackProvider.notifier).stopPlayback();
      };
      // 主控模式下 handler 层的 play/pause/seek 转发给 video 元素，
      // 覆盖媒体会话按键 / 恢复播放进度等不经 PlayerNotifier 的调用路径。
      _audioHandler.onPlayHlsVideo = () {
        ref.read(webVideoPlaybackProvider.notifier).play();
      };
      _audioHandler.onPauseHlsVideo = () {
        ref.read(webVideoPlaybackProvider.notifier).pause();
      };
      _audioHandler.onSeekHlsVideo = (position) {
        ref.read(webVideoPlaybackProvider.notifier).seek(position);
      };
    }

    // 切歌前主动通知后端 cancel 旧 song 的进行中工作（issue #79）。
    // fire-and-forget：不阻塞 setAudioSource，失败也不影响播放主路径。
    _audioHandler.notifySongActivated = (int songId) {
      final dio = ref.read(dioProvider);
      unawaited(
        dio.post('/api/v1/songs/$songId/activate').catchError((e) {
          debugPrint('[Player] activate notify failed (ignored): $e');
          return Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 0,
          );
        }),
      );
    };

    // Android Auto 媒体浏览数据源
    _audioHandler.mediaBrowseDataSource = ApiMediaBrowseDataSource(
      songsApi: ref.read(songsApiProvider),
      playlistApi: ref.read(playlistApiProvider),
    );
    _audioHandler.onPlayFromBrowse = (Song song) async {
      await playSong(song);
    };

    _initListeners();
    _initLiveActivityListeners();
    // Web HLS 视频主控模式：监听 video 元素的播放状态，合并到 PlayerState。
    if (kIsWeb) {
      ref.listen<WebVideoPlaybackState>(webVideoPlaybackProvider, (prev, next) {
        if (!next.isActive) return;
        state = state.copyWith(
          isPlaying: next.isPlaying,
          isBuffering: next.isBuffering,
          currentTime: next.position,
          duration: next.duration,
        );
        // 视频播放结束 → 触发歌曲完成
        if (prev != null &&
            prev.isPlaying &&
            !next.isPlaying &&
            next.position > Duration.zero &&
            next.duration > Duration.zero &&
            (next.duration - next.position).inSeconds < 2) {
          _onSongCompleted();
        }
      });
    }
    ref.onDispose(() {
      _disposed = true;
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription?.cancel();
      _systemVolumeSubscription?.cancel();
      _sleepTimerLogic.dispose();
      _prefetchCancelToken?.cancel('disposed');
      _saveDebounceTimer?.cancel();
      _positionSaveTimer?.cancel();
      LiveActivityService().endActivity();
    });

    // 从本地存储加载音量和播放模式设置
    _loadPreferences();

    return PlayerState.initial;
  }

  /// 是否使用系统音量控制（仅移动端）
  bool get _useSystemVolume => !kIsWeb && PlatformUtils.isMobile;

  /// 从本地存储加载播放器偏好设置
  Future<void> _loadPreferences() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final playModeString = prefs.getPlayMode();
      final playMode = PlayMode.fromString(playModeString);

      debugPrint('[Player] Loaded preferences: playMode=$playModeString');

      // 更新播放模式
      _modeResolver.onModeChanged(playMode);
      state = state.copyWith(playMode: playMode);

      if (_useSystemVolume) {
        // 移动平台：加载系统音量，just_audio 固定最大
        VolumeController().showSystemUI = false;
        final systemVolume = await VolumeController().getVolume();
        state = state.copyWith(volume: (systemVolume * 100).clamp(0.0, 100.0));
        await _audioHandler.setVolume(1.0);
      } else {
        // 桌面/Web 平台：使用 just_audio 播放器音量
        final savedVolume = prefs.getVolume();
        state = state.copyWith(volume: savedVolume.clamp(0.0, 100.0));
        await _audioHandler.setVolume(state.volume / 100);
      }
      // 恢复播放队列
      await _restorePlaybackState(prefs);
      // 打开客户端后自动播放（纯本地开关，默认关闭）：仅在成功恢复出当前歌曲时
      // 触发，复用 _playCurrent 路径会自动 seek 回上次进度
      // （songloft-org/songloft-player#19）
      if (prefs.getAutoPlayOnLaunch() && state.hasSong) {
        debugPrint('[Player] Auto-play on launch enabled, resuming playback');
        final gen = ++_playGeneration;
        await _playCurrent(gen);
      }
      // 歌词 Provider 的 eager 创建改由根 widget（SongloftApp）负责：player 是
      // lyricStateProvider 的被依赖方（LyricNotifier.build 里 watch 本 Provider），
      // 若在此处 read(lyricStateProvider) 会形成 CircularDependencyError。
    } catch (e) {
      debugPrint('[Player] Failed to load preferences: $e');
      await _audioHandler.setVolume(state.volume / 100);
    }
  }

  Future<void> _restorePlaybackState(AppPreferences prefs) async {
    try {
      final snapshot = await _playbackStorage.loadQueue();
      final savedQueue = snapshot.songs;
      if (savedQueue.isEmpty) return;

      final savedIndex = snapshot.currentIndex ?? prefs.getCurrentIndex();
      final safeIndex = savedIndex.clamp(0, savedQueue.length - 1);
      final savedPositionMs = prefs.getPositionMs();
      final savedSong = savedQueue[safeIndex];
      _playbackResumeState.restore(
        songId: savedSong.id,
        songType: savedSong.type,
        position: Duration(milliseconds: savedPositionMs),
      );
      final savedContext = prefs.getSourceContext();

      state = state.copyWith(
        playlist: savedQueue,
        currentIndex: safeIndex,
        currentSong: savedQueue[safeIndex],
        playbackContext: savedContext,
        clearPlaybackContext: savedContext == null,
      );

      debugPrint(
        '[Player] Restored playback state: ${savedQueue.length} songs, '
        'index=$safeIndex, position=${savedPositionMs}ms',
      );
    } catch (e) {
      debugPrint('[Player] Failed to restore playback state: $e');
    }
  }

  void _savePlaybackState() {
    _saveDebounceTimer?.cancel();
    if (_webPlaybackPersistenceDisabled && state.playlist.isNotEmpty) return;
    _saveDebounceTimer = Timer(
      const Duration(milliseconds: _saveDebounceMs),
      () async {
        try {
          final prefs = await ref.read(appPreferencesProvider.future);
          if (state.playlist.isEmpty) {
            await _playbackStorage.clear();
            await prefs.clearPlaybackState();
            _webPlaybackPersistenceDisabled = false;
          } else {
            final result = await _playbackStorage.saveQueue(
              state.playlist,
              currentIndex: state.currentIndex,
            );
            if (!result.saved) {
              if (kIsWeb) _webPlaybackPersistenceDisabled = true;
              return;
            }
            await prefs.setCurrentIndex(result.persistedIndex);
            await prefs.setPositionMs(state.currentTime.inMilliseconds);
            await prefs.setSourceContext(state.playbackContext);
            if (state.playbackContext != null && state.currentSong != null) {
              await prefs.setLastPlayedSong(
                state.playbackContext!,
                state.currentSong!.id,
              );
            }
          }
        } catch (e) {
          if (kIsWeb) _webPlaybackPersistenceDisabled = true;
          debugPrint('[Player] Failed to save playback state: $e');
        }
      },
    );
  }

  void _startPositionSaveTimer() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(
      const Duration(seconds: _positionSaveIntervalSec),
      (_) async {
        if (!state.isPlaying ||
            state.currentIndex < 0 ||
            _webPlaybackPersistenceDisabled) {
          return;
        }
        try {
          final prefs = await ref.read(appPreferencesProvider.future);
          await prefs.setPositionMs(state.currentTime.inMilliseconds);
        } catch (e) {
          if (kIsWeb) _webPlaybackPersistenceDisabled = true;
          debugPrint('[Player] Failed to save position: $e');
        }
      },
    );
  }

  void _stopPositionSaveTimer() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
  }

  /// 初始化监听器
  void _initListeners() {
    _initWidgetActionChannel();

    // 监听播放位置
    _positionSubscription = _audioHandler.positionStream.listen((position) {
      if (_playGeneration != _playGenerationAtSource) return;
      state = state.copyWith(currentTime: position);
      // 剩余≤30s 时保险再触发一次预拉取（防止首次触发太早使转码未完成）
      _maybeFireLateStagePrefetch(position);
    });

    // 监听总时长
    _durationSubscription = _audioHandler.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
        // 同时更新通知栏的 duration
        _audioHandler.updateDuration(duration);
      }
    });

    // 监听播放状态
    _playerStateSubscription = _audioHandler.playerStateStream.listen((
      playerState,
    ) {
      final isLive = state.currentSong?.isLive ?? false;
      final wasPlaying = state.isPlaying;
      state = state.copyWith(
        isPlaying: playerState.playing,
        isBuffering:
            playerState.processingState == ja.ProcessingState.loading ||
            (playerState.processingState == ja.ProcessingState.buffering &&
                !isLive),
      );
      if (wasPlaying != playerState.playing) {
        _liveActivity.updatePlaybackState(
          isPlaying: playerState.playing,
          progress: state.progress,
        );
        HomeWidgetService().updatePlaybackState(playerState.playing);
        if (playerState.playing) {
          HomeWidgetService().startProgressUpdates(
            currentPosition: () => _audioHandler.playbackState.value.position,
            currentDuration:
                () => _audioHandler.mediaItem.value?.duration ?? Duration.zero,
          );
        } else {
          HomeWidgetService().stopProgressUpdates();
        }
      }
    });
    // 歌曲结束通过 _audioHandler.onSongCompleted 回调处理

    // 监听系统音量变化（仅移动平台）
    if (_useSystemVolume) {
      _systemVolumeSubscription = VolumeController().listener((volume) {
        // volume 是 0.0-1.0，转换为 0-100
        final volumePercent = (volume * 100).clamp(0.0, 100.0);
        if ((volumePercent - state.volume).abs() > 0.5) {
          state = state.copyWith(
            volume: volumePercent,
            clearPreviousVolume: true,
          );
        }
      });
    }

    // 监听收藏状态变化，同步通知栏图标
    ref.listen(favoriteProvider, (_, _) {
      _updateNotificationFavorite();
      _syncHomeWidgetFavorite();
    });
  }

  /// 初始化 Live Activity 服务
  void _initLiveActivityListeners() {
    _liveActivity = LiveActivityService();
    if (!kIsWeb && PlatformUtils.isIOS) {
      _lifecycleListener = AppLifecycleListener(
        onResume: () => _liveActivity.clearSupportedCache(),
      );
      ref.onDispose(() => _lifecycleListener?.dispose());
    }
  }

  late final LiveActivityService _liveActivity;
  AppLifecycleListener? _lifecycleListener;

  /// 通知 Live Activity 当前歌曲变更
  void _syncLiveActivitySong(Song? song) {
    if (song == null) {
      _liveActivity.endActivity();
      return;
    }
    // lyricStateProvider 首次读取会触发 LyricNotifier.build()，其内部 watch
    // playerStateProvider；若在 _playCurrent 调用栈内同步 read，会与正在计算的
    // playerStateProvider 形成 build 期循环依赖（CircularDependencyError），
    // 导致首次播放被中断、需再点一次才生效。改为微任务延后读取：此刻 playerState
    // 已就绪，读取仅建立单向数据依赖，不再构成循环。
    Future.microtask(() {
      if (_disposed) return;
      final lyricState = ref.read(lyricStateProvider);
      _liveActivity.startActivity(
        title: song.title,
        artist: song.artist ?? '',
        lyricLine:
            lyricState.currentLyricText.isNotEmpty
                ? lyricState.currentLyricText
                : null,
        artUrl:
            song.coverUrl != null
                ? UrlHelper.buildCoverUrl(song.coverUrl!, width: 256)
                : null,
      );
    });
  }

  void _syncHomeWidgetSong(Song? song) {
    final widget = HomeWidgetService();
    if (song == null) {
      widget.clearNowPlaying();
      return;
    }
    final favState = ref.read(favoriteProvider);
    final isRadio = song.type == 'radio';
    final isFav =
        isRadio
            ? favState.favoriteRadioIds.contains(song.id)
            : favState.favoriteSongIds.contains(song.id);
    widget.updateNowPlaying(
      title: song.title,
      artist: song.artist ?? '',
      artUrl:
          song.coverUrl != null
              ? UrlHelper.buildCoverUrl(song.coverUrl!, width: 256)
              : null,
      isPlaying: state.isPlaying,
      isFavorite: isFav,
      position: Duration.zero,
      duration: Duration(milliseconds: (song.duration * 1000).toInt()),
    );
    if (state.isPlaying) {
      widget.startProgressUpdates(
        currentPosition: () => _audioHandler.playbackState.value.position,
        currentDuration:
            () => _audioHandler.mediaItem.value?.duration ?? Duration.zero,
      );
    } else {
      widget.stopProgressUpdates();
    }
  }

  /// 上报播放事件（fire-and-forget，失败只打日志，不影响播放）。
  ///
  /// [context] 只在 type=play 时传：后端据此写入播放历史。
  /// finish 是同一首歌的重复信息；skip 上报的是**上一首**歌，那时 state 里的上下文
  /// 可能已经切到新歌单了，带上会把上一首错记到新上下文名下。
  void _notifyPlayEvent(int songId, String type, {PlaybackContext? context}) {
    ref
        .read(songsApiProvider)
        .songPlayed(songId, type: type, context: context)
        .catchError((e) {
          debugPrint('[Player] playEvent($type) notify failed: $e');
        });
  }

  /// 歌曲播放完成处理
  void _onSongCompleted() {
    _retryPolicy.recordSuccess();
    debugPrint('[Player] Song completed, playMode: ${state.playMode}');

    final completedSong = state.currentSong;
    if (completedSong != null) {
      _notifyPlayEvent(completedSong.id, 'finish');
    }

    // 睡眠定时器钩子：优先于播放模式分支，覆盖所有 playMode
    if (_sleepTimerLogic.onSongCompleted()) {
      debugPrint('[Player] Sleep timer: pause after songs reached 0');
      _audioHandler.pause();
      state = state.copyWith(clearSleepTimer: true);
      return;
    }
    // 同步 afterSongs 模式的 remainingSongs 到 UI state
    final updatedTimerStatus = _sleepTimerLogic.status;
    if (updatedTimerStatus != null &&
        updatedTimerStatus.mode == SleepTimerMode.afterSongs) {
      debugPrint(
        '[Player] Sleep timer: ${updatedTimerStatus.remainingSongs} songs remaining',
      );
      state = state.copyWith(sleepTimer: updatedTimerStatus);
    }

    if (state.playlist.isEmpty) {
      debugPrint('[Player] Playlist empty, stopping');
      _audioHandler.stop();
      return;
    }

    switch (_completionRouter.resolve(
      mode: state.playMode,
      currentIndex: state.currentIndex,
      playlistLength: state.playlist.length,
    )) {
      case CompletionAction.replayCurrent:
        // 单曲循环：重新加载当前歌曲。
        // 不能用 seek(0)+play()：部分平台（Web/mediakit 自研平台层）在
        // completed 状态下 seek 不会重新触发 completed 边沿，导致第二遍后停住
        // （songloft-org/songloft#284）。复用 togglePlay 对 completed 的处理路径。
        {
          debugPrint('[Player] Single loop: reloading current song');
          final gen = ++_playGeneration;
          unawaited(
            _playCurrent(gen).catchError((e, st) {
              debugPrint('[Player] single loop replay failed: $e');
              _audioHandler.stop();
            }),
          );
        }
        break;
      case CompletionAction.pause:
        // 单曲播放：播完停止，不循环、不切换下一首
        debugPrint('[Player] SinglePlay mode: pausing after song completed');
        _audioHandler.pause();
        break;
      case CompletionAction.stopEndOfList:
        debugPrint('[Player] Order mode: reached end of playlist, stopping');
        state = state.copyWith(isPlaying: false);
        _audioHandler.stop();
        break;
      case CompletionAction.playNext:
        debugPrint('[Player] Playing next song');
        unawaited(
          playNext().catchError((e, st) {
            debugPrint('[Player] playNext failed after song completed: $e');
            _audioHandler.stop();
          }),
        );
        break;
    }
  }

  /// 播放单曲（添加到播放列表并播放）
  Future<void> playSong(Song song) async {
    debugPrint(
      '[Player] playSong: ${song.title} (id: ${song.id}, type: ${song.type})',
    );
    _retryPolicy.recordSuccess();
    _playbackResumeState.clear();
    // 检查是否已在播放列表中
    final existingIndex = state.playlist.indexWhere(
      (s) => s.id == song.id && s.type == song.type,
    );

    if (existingIndex >= 0) {
      // 已存在，直接跳转播放
      debugPrint('[Player] Song already in playlist at index $existingIndex');
      await _playAtIndex(existingIndex);
    } else {
      // 添加到播放列表末尾并播放
      final newPlaylist = [...state.playlist, song];
      final newIndex = newPlaylist.length - 1;
      debugPrint('[Player] Adding song to playlist at index $newIndex');
      state = state.copyWith(
        playlist: newPlaylist,
        currentIndex: newIndex,
        currentSong: song,
        clearPlaybackContext: true,
      );
      final gen = ++_playGeneration;
      await _playCurrent(gen);
      if (gen == _playGeneration) {
        _savePlaybackState();
      }
    }
  }

  void _toggleFavoriteFromNotification() {
    final song = state.currentSong;
    if (song == null) return;
    debugPrint('[Player] Toggle favorite from notification: ${song.id}');
    unawaited(_toggleSongFavorite(song.id, song.type));
  }

  Future<void> _toggleSongFavorite(int songId, String songType) async {
    try {
      final notifier = ref.read(favoriteProvider.notifier);
      final isRadio = songType == 'radio';
      if (isRadio) {
        await notifier.toggleRadioFavorite(songId);
      } else {
        await notifier.toggleFavorite(songId);
      }
      _updateNotificationFavorite();
    } catch (e) {
      debugPrint('[Player] Toggle favorite failed: $e');
    }
  }

  void _updateNotificationFavorite() {
    final song = state.currentSong;
    if (song == null) return;
    final favState = ref.read(favoriteProvider);
    final isRadio = song.type == 'radio';
    final isFav =
        isRadio
            ? favState.favoriteRadioIds.contains(song.id)
            : favState.favoriteSongIds.contains(song.id);
    _audioHandler.setFavorited(isFav);
  }

  void _syncHomeWidgetFavorite() {
    final song = state.currentSong;
    if (song == null) return;
    final favState = ref.read(favoriteProvider);
    final isRadio = song.type == 'radio';
    final isFav =
        isRadio
            ? favState.favoriteRadioIds.contains(song.id)
            : favState.favoriteSongIds.contains(song.id);
    HomeWidgetService().updateFavoriteState(isFav);
  }

  static const _widgetActionChannel = MethodChannel(
    'com.songloft/widget_action',
  );

  void _initWidgetActionChannel() {
    if (!PlatformUtils.isAndroid) return;
    _widgetActionChannel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction' && call.arguments == 'favorite') {
        _toggleFavoriteFromNotification();
      }
    });
  }

  /// 播放歌单
  /// 替换整个播放队列并起播。
  ///
  /// [context] 是队列的来源上下文（歌单 / 歌手 / 专辑 等），决定播放历史记到哪儿、
  /// 以及各处「正在播放」高亮。[sourcePlaylistId] 是它的歌单专用简写，保留下来供
  /// JS 插件的 `player.setQueue` 使用；两者都传时 [context] 优先。
  ///
  /// [keepContext] 用于「在当前队列内换一首歌」（队列页 / 播放抽屉）：那种场景没有新
  /// 上下文可传，但也不该把已有的清空。
  Future<void> playPlaylist(
    List<Song> songs, {
    int startIndex = 0,
    int? sourcePlaylistId,
    PlaybackContext? context,
    bool keepContext = false,
  }) async {
    debugPrint(
      '[Player] playPlaylist: ${songs.length} songs, startIndex: $startIndex',
    );
    _retryPolicy.recordSuccess();
    if (songs.isEmpty) {
      debugPrint('[Player] playPlaylist: empty songs list, returning');
      return;
    }

    _playbackResumeState.clear();

    // 取消之前的预加载
    _prefetchCancelToken?.cancel('operation changed');

    // 切换上下文前，保存离开的上下文的最后播放歌曲
    final departingCtx = state.playbackContext;
    final departingSong = state.currentSong;
    if (departingCtx != null && departingSong != null) {
      ref.read(appPreferencesProvider.future).then((prefs) {
        prefs.setLastPlayedSong(departingCtx, departingSong.id);
      });
    }

    // 递增代次，使正在进行的后台加载自动取消
    _loadGeneration = _queueLoader.invalidate();

    final safeIndex = startIndex.clamp(0, songs.length - 1);
    debugPrint(
      '[Player] playPlaylist: starting with song: ${songs[safeIndex].title}',
    );
    _modeResolver.onQueueChanged();

    final resolvedContext =
        keepContext
            ? state.playbackContext
            : (context ??
                (sourcePlaylistId == null
                    ? null
                    : PlaybackContext.playlist(sourcePlaylistId)));

    state = state.copyWith(
      playlist: List.from(songs),
      currentIndex: safeIndex,
      currentSong: songs[safeIndex],
      playbackContext: resolvedContext,
      clearPlaybackContext: resolvedContext == null,
    );

    final gen = ++_playGeneration;
    await _playCurrent(gen);
    if (gen == _playGeneration) {
      _savePlaybackState();
    }
  }

  /// 添加到当前播放列表
  void addToPlaylist(List<Song> songs) {
    if (songs.isEmpty) return;

    final queue = PlayQueue(
      songs: state.playlist,
      currentIndex: state.currentIndex,
    ).add(songs);

    state = state.copyWith(playlist: queue.songs);
    _savePlaybackState();
  }

  /// 将歌曲插入到播放列表的指定位置
  /// 用于撤销删除等场景，不会触发播放
  void insertToPlaylist(int index, Song song) {
    final queue = PlayQueue(
      songs: state.playlist,
      currentIndex: state.currentIndex,
    ).insert(index, song);

    state = state.copyWith(
      playlist: queue.songs,
      currentIndex: queue.currentIndex,
    );
    _savePlaybackState();
  }

  /// 暂停/播放切换
  Future<void> togglePlay() async {
    if (!state.hasSong) {
      debugPrint('[Player] togglePlay: no song to play');
      return;
    }

    // Web HLS 视频主控模式：控制 video 元素而非 just_audio
    if (kIsWeb && _audioHandler.hlsVideoPrimaryMode) {
      final vp = ref.read(webVideoPlaybackProvider.notifier);
      if (state.isPlaying) {
        debugPrint('[Player] togglePlay: pausing (HLS video primary)');
        vp.pause();
      } else {
        debugPrint('[Player] togglePlay: playing (HLS video primary)');
        vp.play();
      }
      return;
    }

    if (state.isPlaying) {
      if (state.currentSong?.isLive ?? false) {
        debugPrint('[Player] togglePlay: stopping live stream');
        await _audioHandler.stop();
      } else {
        debugPrint('[Player] togglePlay: pausing');
        await _audioHandler.pause();
      }
    } else {
      // idle / completed 状态下需要重新加载当前歌曲：
      // - idle：无音频源（如后台播放失败后）
      // - completed：歌曲已播完，简单调用 play() 在部分平台上不会自动 seek 到
      //   开头重播（ExoPlayer STATE_ENDED 下 setPlayWhenReady 不会重启），
      //   且切换过音质后需要用新 URL 重新加载
      final ps = _audioHandler.processingState;
      if (ps == ja.ProcessingState.idle || ps == ja.ProcessingState.completed) {
        debugPrint('[Player] togglePlay: player $ps, re-loading current song');
        _retryPolicy.recordSuccess();
        final gen = ++_playGeneration;
        await _playCurrent(gen);
      } else {
        debugPrint('[Player] togglePlay: resuming');
        await _audioHandler.play();
      }
    }
  }

  /// 播放下一首
  Future<void> playNext() async {
    debugPrint(
      '[Player] playNext: currentIndex: ${state.currentIndex}, playlistLength: ${state.playlist.length}',
    );
    if (state.playlist.isEmpty) {
      debugPrint('[Player] playNext: playlist is empty');
      return;
    }

    final nextIdx = _modeResolver.nextIndex(
      currentIndex: state.currentIndex,
      length: state.playlist.length,
    );
    if (nextIdx == null) {
      debugPrint(
        '[Player] playNext: no next index (end of playlist or stopped)',
      );
      return;
    }
    debugPrint(
      '[Player] playNext: nextIndex: $nextIdx (mode: ${state.playMode})',
    );

    await _playAtIndex(nextIdx);
  }

  /// 投屏专用：仅将播放队列推进到下一首（更新 currentIndex/currentSong），
  /// 不触发本地播放。用于 DLNA 投屏时设备播完当前曲后推进歌单。
  /// 返回推进后的当前歌曲；顺序模式到达末尾时返回 null。
  /// 注意：single / singlePlay 模式由投屏层单独处理，不应调用此方法。
  Song? advanceForCasting() {
    if (state.playlist.isEmpty) return null;

    final nextIdx = _modeResolver.nextIndex(
      currentIndex: state.currentIndex,
      length: state.playlist.length,
    );
    if (nextIdx == null) return null;

    // 兜底：任何情况下都不越界访问
    if (nextIdx < 0 || nextIdx >= state.playlist.length) return null;

    _modeResolver.markPlayed(nextIdx);
    state = state.copyWith(
      currentIndex: nextIdx,
      currentSong: state.playlist[nextIdx],
      currentTime: Duration.zero,
      duration: Duration.zero,
    );
    _modeResolver.preSelectNext(
      currentIndex: state.currentIndex,
      length: state.playlist.length,
    );
    _savePlaybackState();
    return state.currentSong;
  }

  /// 播放上一首
  Future<void> playPrev() async {
    _retryPolicy.recordSuccess();
    debugPrint(
      '[Player] playPrev: currentIndex: ${state.currentIndex}, currentTime: ${state.currentTime.inSeconds}s',
    );
    if (state.playlist.isEmpty) {
      debugPrint('[Player] playPrev: playlist is empty');
      return;
    }

    // 如果当前播放超过 3 秒，重新开始当前歌曲
    if (state.currentTime.inSeconds > 3) {
      debugPrint('[Player] playPrev: seeking to start of current song');
      await _audioHandler.seek(Duration.zero);
      return;
    }

    final prevIdx = _modeResolver.prevIndex(
      currentIndex: state.currentIndex,
      length: state.playlist.length,
      currentPosition: state.currentTime,
    );
    if (prevIdx == null) {
      debugPrint('[Player] playPrev: no prev index, seeking to start');
      await _audioHandler.seek(Duration.zero);
      return;
    }
    if (prevIdx == state.currentIndex) {
      debugPrint('[Player] playPrev: same index, seeking to start');
      await _audioHandler.seek(Duration.zero);
      return;
    }
    debugPrint(
      '[Player] playPrev: prevIndex: $prevIdx (mode: ${state.playMode})',
    );

    await _playAtIndex(prevIdx);
  }

  /// 跳转进度
  Future<void> seek(Duration position) async {
    // Web HLS 视频主控模式：seek video 元素
    if (kIsWeb && _audioHandler.hlsVideoPrimaryMode) {
      ref.read(webVideoPlaybackProvider.notifier).seek(position);
      return;
    }
    await _audioHandler.seek(position);
  }

  /// 相对当前进度快进/快退，clamp 到 [0, duration]。
  /// 直播流 / 未知时长时 no-op（seek 无意义且可能异常）。
  Future<void> seekBy(Duration delta) async {
    if (!state.hasSong) return;
    if (state.currentSong?.isLive ?? false) return;
    final total = state.duration;
    if (total <= Duration.zero) return;
    var target = state.currentTime + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    await seek(target);
  }

  /// 设置音量 (0-100)
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 100.0);
    state = state.copyWith(volume: clampedVolume, clearPreviousVolume: true);

    if (_useSystemVolume) {
      // 移动平台：控制系统音量
      try {
        VolumeController().setVolume(clampedVolume / 100);
        debugPrint('[Player] Set system volume: ${clampedVolume / 100}');
      } catch (e) {
        debugPrint('[Player] Failed to set system volume: $e');
      }
    } else {
      // 桌面/Web 平台：使用 just_audio 播放器音量
      await _audioHandler.setVolume(clampedVolume / 100);
      debugPrint('[Player] Set player volume: ${clampedVolume / 100}');
      try {
        final prefs = await ref.read(appPreferencesProvider.future);
        await prefs.setVolume(clampedVolume);
        pushPreferencesToServer(ref.read(dioProvider));
      } catch (e) {
        debugPrint('[Player] Failed to save volume: $e');
      }
    }
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.5, 2.0);
    state = state.copyWith(speed: clampedSpeed);
    await _audioHandler.setSpeed(clampedSpeed);
    debugPrint('[Player] Set speed: ${clampedSpeed}x');
  }

  /// 切换静音
  Future<void> toggleMute() async {
    if (state.isMuted) {
      // 恢复音量
      final restoreVolume = state.previousVolume ?? 50;
      await setVolume(restoreVolume);
    } else {
      // 静音
      state = state.copyWith(previousVolume: state.volume);
      await setVolume(0);
    }
  }

  /// 设置播放模式
  Future<void> setPlayMode(PlayMode mode) async {
    _modeResolver.onModeChanged(mode);
    state = state.copyWith(playMode: mode);

    // 保存到本地存储
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setPlayMode(mode.toStorageString());
      pushPreferencesToServer(ref.read(dioProvider));
      debugPrint('[Player] Saved playMode: ${mode.toStorageString()}');
    } catch (e) {
      debugPrint('[Player] Failed to save playMode: $e');
    }

    // 如果当前正在播放，重新预选下一首并预加载
    if (state.playlist.isNotEmpty &&
        state.currentIndex >= 0 &&
        state.isPlaying) {
      _prefetchCancelToken?.cancel('play mode changed');
      _prefetchStrategy.onSongChanged();
      _modeResolver.preSelectNext(
        currentIndex: state.currentIndex,
        length: state.playlist.length,
      );
      // 副作用：刷新 SecureStorageService.cachedAccessToken,供 UrlHelper 使用
      await _secureStorage.getAccessToken();
      _prefetchNextSong();
    }
  }

  /// 从播放列表删除
  Future<void> removeFromPlaylist(int index) async {
    if (index < 0 || index >= state.playlist.length) return;

    final wasCurrentIndex = state.currentIndex;

    final result = PlayQueue(
      songs: state.playlist,
      currentIndex: state.currentIndex,
    ).removeAt(index);

    if (result.shouldStop) {
      _audioHandler.stop();
    }

    state = state.copyWith(
      playlist: result.queue.songs,
      currentIndex: result.queue.currentIndex,
      currentSong: result.currentSong,
      clearCurrentSong: result.currentSong == null,
    );
    if (result.currentSong == null) {
      _syncLiveActivitySong(null);
      _syncHomeWidgetSong(null);
    }
    _savePlaybackState();

    if (index == wasCurrentIndex && result.currentSong != null) {
      await _playAtIndex(result.queue.currentIndex);
    }
  }

  /// 拖拽排序播放列表
  /// 拖拽排序（经典 onReorder 语义：newIndex 为"移除前"索引）。
  /// 供 JS 插件 reorderQueue 入口复用；widget 侧走 onReorderItem → [moveInPlaylist]。
  void reorderPlaylist(int oldIndex, int newIndex) {
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    moveInPlaylist(oldIndex, insertIndex);
  }

  /// 将 oldIndex 处歌曲移动到 insertIndex。
  /// onReorderItem 语义：insertIndex 已是"移除后"的最终目标索引，无需再调整。
  void moveInPlaylist(int oldIndex, int insertIndex) {
    if (oldIndex == insertIndex) return;

    final queue = PlayQueue(
      songs: state.playlist,
      currentIndex: state.currentIndex,
    ).move(oldIndex, insertIndex);

    state = state.copyWith(
      playlist: queue.songs,
      currentIndex: queue.currentIndex,
    );
    _savePlaybackState();
  }

  /// 清空播放列表
  void clearPlaylist() {
    // 取消之前的预加载
    _prefetchCancelToken?.cancel('operation changed');
    // 递增代次，使正在进行的后台加载自动取消
    _loadGeneration = _queueLoader.invalidate();
    _retryPolicy.recordSuccess();
    _playbackResumeState.clear();
    _audioHandler.stop();
    _modeResolver.onQueueChanged();
    _stopPositionSaveTimer();
    state = state.copyWith(
      playlist: [],
      currentIndex: -1,
      clearCurrentSong: true,
      isPlaying: false,
      currentTime: Duration.zero,
      duration: Duration.zero,
      clearPlaybackContext: true,
    );
    _syncLiveActivitySong(null);
    _syncHomeWidgetSong(null);
    _savePlaybackState();
  }

  /// 读取歌单持久化的视图排序偏好（PUT /playlists/{id}/sort 写入），
  /// 拿不到时退回 position/asc（等同不指定排序时后端的默认行为）。
  /// 播放整单 / 播放历史续播都要用这个偏好，而不是想当然地按 position 拉，
  /// 否则播放队列顺序会和歌单详情页里看到的自定义排序不一致
  /// （songloft-org/songloft#381）。
  Future<(String, String)> _playlistSortOrder(int playlistId) async {
    try {
      final playlist = await ref
          .read(playlistApiProvider)
          .getPlaylist(playlistId);
      return (playlist.sortBy, playlist.sortOrder);
    } catch (e) {
      debugPrint('[Player] 获取歌单 $playlistId 排序偏好失败，回退默认排序: $e');
      return ('position', 'asc');
    }
  }

  /// 批量版 [_playlistSortOrder]，供合并播放多个歌单时并发取各自的排序偏好。
  Future<Map<int, (String, String)>> _playlistSortOrders(
    List<int> playlistIds,
  ) async {
    final entries = await Future.wait(
      playlistIds.map((id) async => MapEntry(id, await _playlistSortOrder(id))),
    );
    return Map.fromEntries(entries);
  }

  /// 通过歌单 ID 播放全部歌曲
  /// 策略：先取第一页（100首）立即开始播放，后台异步加载剩余歌曲
  /// 使用 _loadGeneration 防止竞态：用户切换歌单或清空时自动取消旧的后台加载
  /// [playlistId] 歌单 ID
  /// 返回用于展示的总歌曲数（-1 表示失败）
  Future<int> playPlaylistById(int playlistId) async {
    final playlistApi = ref.read(playlistApiProvider);
    const firstPageLimit = 10;

    debugPrint('[Player] playPlaylistById: start, playlistId=$playlistId');
    _retryPolicy.recordSuccess();
    try {
      final (sort, order) = await _playlistSortOrder(playlistId);
      final firstPageResponse = await playlistApi.getPlaylistSongs(
        playlistId,
        limit: firstPageLimit,
        offset: 0,
        sort: sort,
        order: order,
      );
      final firstPageSongs = firstPageResponse.songs;
      final total = firstPageResponse.total;

      debugPrint(
        '[Player] playPlaylistById: firstPage=${firstPageSongs.length}, total=$total',
      );

      if (firstPageSongs.isEmpty) {
        debugPrint('[Player] playPlaylistById: playlist is empty');
        return 0;
      }

      // playPlaylist 内部会递增 _loadGeneration，取消之前的后台加载
      // 尝试从上次播放位置恢复
      final prefs = await ref.read(appPreferencesProvider.future);
      final lastSongId = prefs.getLastPlayedSong(
        PlaybackContext.playlist(playlistId),
      );
      int startIndex;
      if (lastSongId != null) {
        final resumeIndex = firstPageSongs.indexWhere(
          (s) => s.id == lastSongId,
        );
        startIndex =
            resumeIndex >= 0
                ? resumeIndex
                : (state.playMode == PlayMode.random
                    ? _random.nextInt(firstPageSongs.length)
                    : 0);
      } else {
        startIndex =
            state.playMode == PlayMode.random
                ? _random.nextInt(firstPageSongs.length)
                : 0;
      }
      await playPlaylist(
        firstPageSongs,
        startIndex: startIndex,
        context: PlaybackContext.playlist(playlistId),
      );

      if (total > firstPageSongs.length) {
        // 记录当前代次，传给后台加载任务用于检测是否过期
        final generation = _loadGeneration;
        debugPrint(
          '[Player] playPlaylistById: starting background load, generation=$generation, offset=${firstPageSongs.length}',
        );
        _loadRemainingSongsById(
          playlistId,
          playlistApi,
          firstPageSongs.length,
          total,
          generation,
          sort: sort,
          order: order,
        );
      } else {
        debugPrint('[Player] playPlaylistById: all songs loaded in first page');
        ref.read(playlistNotifierProvider.notifier).touchPlaylist(playlistId);
      }

      return total;
    } catch (e, st) {
      debugPrint('[Player] playPlaylistById error: $e\n$st');
      return -1;
    }
  }

  /// 从歌单某首歌开始播放（已加载分页 + 后台补齐整个队列）。
  ///
  /// 用户点击歌单内某首歌时的入口。[loadedSongs] 是列表当前已分页加载的歌曲，
  /// 立即以 [startIndex] 为起点开始播放；若歌单还有未加载的歌曲（[total] >
  /// 已加载数），则后台按相同的 [sort]/[order]/[keyword] 继续补齐，使播放队列
  /// 覆盖整个歌单而非被截断到已加载页（修复 songloft-org/songloft#299）。
  Future<void> playPlaylistFromLoaded({
    required List<Song> loadedSongs,
    required int startIndex,
    required int playlistId,
    required int total,
    String sort = 'position',
    String order = 'asc',
    String keyword = '',
  }) async {
    if (loadedSongs.isEmpty) return;
    final playlistApi = ref.read(playlistApiProvider);
    // playPlaylist 内部会递增 _loadGeneration，取消之前的后台加载
    await playPlaylist(
      loadedSongs,
      startIndex: startIndex,
      context: PlaybackContext.playlist(playlistId),
    );

    if (total > loadedSongs.length) {
      final generation = _loadGeneration;
      debugPrint(
        '[Player] playPlaylistFromLoaded: starting background load, '
        'generation=$generation, offset=${loadedSongs.length}, total=$total',
      );
      _loadRemainingSongsById(
        playlistId,
        playlistApi,
        loadedSongs.length,
        total,
        generation,
        sort: sort,
        order: order,
        keyword: keyword,
      );
    } else {
      ref.read(playlistNotifierProvider.notifier).touchPlaylist(playlistId);
    }
  }

  /// 从播放历史条目起播。
  ///
  /// 历史条目自带完整 Song，所以先用这一首当队列立即出声（**零额外请求**），
  /// 再在后台把整个上下文补齐成环形旋转队列：
  /// `[目标歌, 目标之后…, 上下文开头…目标之前]`。
  ///
  /// 这样 currentIndex 全程为 0 不动（不牵连随机模式的 PlayModeResolver 状态），
  /// 且歌单与各分面维度走完全同一条路径 —— 不依赖后端
  /// 计算「第几首」，因为分面列表默认按 added_at 排序且无 id tie-break，
  /// 批量扫描导入的歌曲 added_at 会大量相同，序数并不可靠。
  Future<void> playFromHistory({
    required PlaybackContext context,
    required Song song,
  }) async {
    // 刻意不 await 起播就启动补齐：playPlaylist 会一路 await 到音频真正加载完成，
    // 首曲加载慢或播放失败重试（网络歌曲最多 7 次指数退避，可达数十秒）时，
    // 队列补齐会被整段推迟 —— 用户看到队列里只有这一首、切不了歌。
    // playPlaylist 在它的第一个 await 之前会同步递增 _loadGeneration 并写好 state，
    // 所以紧接着读到的代次就是本次播放的代次。
    final playing = playPlaylist([song], startIndex: 0, context: context);
    final generation = _loadGeneration;
    unawaited(
      _fillQueueAroundSong(
        context: context,
        songId: song.id,
        generation: generation,
      ),
    );
    await playing;
  }

  /// 拉取上下文的有序歌曲 ID 列表。顺序与该上下文的分页列表一致。
  /// [sort]/[order] 仅对歌单上下文有意义，传入歌单当前的持久化排序偏好。
  Future<List<int>> _fetchContextSongIds(
    PlaybackContext context, {
    String? sort,
    String? order,
  }) async {
    final playlistId = context.playlistId;
    if (playlistId != null) {
      return ref
          .read(playlistApiProvider)
          .getPlaylistSongIds(playlistId, sort: sort, order: order);
    }
    // 上下文类型不认识（prefs 被写坏、手工深链、playlist 的 key 不是数字…）时必须早退：
    // categorySongsFilter 对未知 field 返回全 null 的过滤器，会退化成「无条件查询」，
    // 把整个曲库拉进播放队列。
    if (!categoryFields.contains(context.type)) {
      debugPrint('[Player] 未知播放上下文类型，跳过队列补齐: ${context.type}');
      return const [];
    }
    final f = categorySongsFilter((field: context.type, value: context.key));
    return ref
        .read(songsApiProvider)
        .getSongIds(
          genre: f.genre,
          artist: f.artist,
          album: f.album,
          language: f.language,
          style: f.style,
          year: f.year,
          decade: f.decade,
        );
  }

  /// 返回按 offset/limit 抓取该上下文歌曲的函数。
  /// [sort]/[order] 仅对歌单上下文有意义，传入歌单当前的持久化排序偏好。
  Future<List<Song>> Function(int offset, int limit) _contextFetcher(
    PlaybackContext context, {
    String? sort,
    String? order,
  }) {
    final playlistId = context.playlistId;
    if (playlistId != null) {
      final playlistApi = ref.read(playlistApiProvider);
      return (offset, limit) async {
        final resp = await playlistApi.getPlaylistSongs(
          playlistId,
          limit: limit,
          offset: offset,
          sort: sort,
          order: order,
        );
        return resp.songs;
      };
    }
    final songsApi = ref.read(songsApiProvider);
    final f = categorySongsFilter((field: context.type, value: context.key));
    return (offset, limit) async {
      final resp = await songsApi.getSongs(
        genre: f.genre,
        artist: f.artist,
        album: f.album,
        language: f.language,
        style: f.style,
        year: f.year,
        decade: f.decade,
        limit: limit,
        offset: offset,
      );
      return resp.songs;
    };
  }

  /// 把目标歌之后、再回卷到开头的上下文歌曲补进队列（环形旋转）。
  Future<void> _fillQueueAroundSong({
    required PlaybackContext context,
    required int songId,
    required int generation,
  }) async {
    try {
      String? sort;
      String? order;
      final playlistId = context.playlistId;
      if (playlistId != null) {
        final (s, o) = await _playlistSortOrder(playlistId);
        sort = s;
        order = o;
      }

      final ids = await _fetchContextSongIds(context, sort: sort, order: order);
      if (_loadGeneration != generation || ids.isEmpty) return;

      final fetch = _contextFetcher(context, sort: sort, order: order);
      final absIndex = ids.indexOf(songId);

      final success = await _queueLoader.loadAroundSong(
        generation: generation,
        targetIndex: absIndex,
        totalCount: ids.length,
        fetch: fetch,
        onBatch: (batch) {
          addToPlaylist(batch);
          // 队列增长后必须重算预选的下一首：起播时队列只有 1 首，
          // random 模式对单曲队列直接返回 0（= 当前这首），
          // 而 playNext 会优先用这个预选值 —— 不重算就会把同一首立刻重播一遍。
          _modeResolver.preSelectNext(
            currentIndex: state.currentIndex,
            length: state.playlist.length,
          );
        },
      );

      if (absIndex < 0 && !_queueLoader.isSuperseded(generation)) {
        // 该歌曲已不在此上下文中（被移出歌单 / 元数据被改）。
        // 提示必须放在补齐之后：_playCurrent 播放成功时会 clearInfoMessage，
        // 而 ids 拉取通常快于音频加载，提前设置会被它清掉、用户什么都看不到。
        final message = l10nOrNull?.playHistorySongMissing;
        if (message != null) {
          state = state.copyWith(infoMessage: message);
        }
      }

      if (success && !_queueLoader.isSuperseded(generation)) {
        _savePlaybackState();
      }
    } catch (e, st) {
      debugPrint('[Player] _fillQueueAroundSong failed: $e\n$st');
    }
  }

  /// 合并播放多个歌单
  /// 第一个歌单立即播放，后续歌单后台加载追加到播放队列
  Future<int> playMultiplePlaylistsById(List<int> playlistIds) async {
    if (playlistIds.isEmpty) return 0;
    if (playlistIds.length == 1) return playPlaylistById(playlistIds.first);

    final playlistApi = ref.read(playlistApiProvider);
    const firstPageLimit = 10;
    const batchLimit = 100;
    const maxRetries = 3;

    debugPrint(
      '[Player] playMultiplePlaylistsById: ${playlistIds.length} playlists',
    );
    _retryPolicy.recordSuccess();

    try {
      final sortPrefs = await _playlistSortOrders(playlistIds);
      final firstId = playlistIds.first;
      final (firstSort, firstOrder) = sortPrefs[firstId]!;
      final firstPageResponse = await playlistApi.getPlaylistSongs(
        firstId,
        limit: firstPageLimit,
        offset: 0,
        sort: firstSort,
        order: firstOrder,
      );
      final firstPageSongs = firstPageResponse.songs;
      final firstTotal = firstPageResponse.total;

      if (firstPageSongs.isEmpty) {
        debugPrint('[Player] playMultiplePlaylistsById: first playlist empty');
        return 0;
      }

      await playPlaylist(firstPageSongs);
      final generation = _loadGeneration;

      _loadRemainingMultiplePlaylists(
        playlistIds,
        playlistApi,
        firstPageSongs.length,
        firstTotal,
        generation,
        batchLimit,
        maxRetries,
        sortPrefs,
      );

      return firstTotal;
    } catch (e, st) {
      debugPrint('[Player] playMultiplePlaylistsById error: $e\n$st');
      return -1;
    }
  }

  /// 后台加载多歌单的剩余歌曲
  /// [sortPrefs] 每个歌单各自的排序偏好（见 [_playlistSortOrders]）
  Future<void> _loadRemainingMultiplePlaylists(
    List<int> playlistIds,
    PlaylistApi playlistApi,
    int firstPlaylistOffset,
    int firstPlaylistTotal,
    int generation,
    int batchLimit,
    int maxRetries,
    Map<int, (String, String)> sortPrefs,
  ) async {
    try {
      // 加载第一个歌单的剩余歌曲
      final (firstSort, firstOrder) = sortPrefs[playlistIds.first]!;
      int offset = firstPlaylistOffset;
      while (offset < firstPlaylistTotal) {
        if (_loadGeneration != generation) return;
        final response = await _fetchWithRetry(
          () => playlistApi.getPlaylistSongs(
            playlistIds.first,
            limit: batchLimit,
            offset: offset,
            sort: firstSort,
            order: firstOrder,
          ),
          maxRetries,
        );
        if (_loadGeneration != generation) return;
        if (response.songs.isEmpty) break;
        addToPlaylist(response.songs);
        offset += batchLimit;
      }

      // 依次加载后续歌单的全部歌曲
      for (int i = 1; i < playlistIds.length; i++) {
        if (_loadGeneration != generation) return;
        final playlistId = playlistIds[i];
        final (sort, order) = sortPrefs[playlistId]!;
        debugPrint(
          '[Player] _loadRemainingMultiplePlaylists: loading playlist $playlistId (${i + 1}/${playlistIds.length})',
        );

        int playlistOffset = 0;
        while (true) {
          if (_loadGeneration != generation) return;
          final response = await _fetchWithRetry(
            () => playlistApi.getPlaylistSongs(
              playlistId,
              limit: batchLimit,
              offset: playlistOffset,
              sort: sort,
              order: order,
            ),
            maxRetries,
          );
          if (_loadGeneration != generation) return;
          if (response.songs.isEmpty) break;
          addToPlaylist(response.songs);
          playlistOffset += batchLimit;
          if (playlistOffset >= response.total) break;
        }
      }

      debugPrint(
        '[Player] _loadRemainingMultiplePlaylists: done, total=${state.playlist.length}',
      );
    } catch (e, st) {
      debugPrint('[Player] _loadRemainingMultiplePlaylists: failed: $e\n$st');
    }
    if (_loadGeneration == generation) {
      _savePlaybackState();
    }
  }

  /// 带重试的歌曲批次加载
  Future<SongListResponse> _fetchWithRetry(
    Future<SongListResponse> Function() fetch,
    int maxRetries,
  ) async {
    for (int retry = 0; retry < maxRetries; retry++) {
      try {
        return await fetch();
      } catch (e) {
        if (retry == maxRetries - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (retry + 1)));
      }
    }
    throw StateError('unreachable');
  }

  /// 后台异步加载剩余歌曲并追加到播放列表，完成后调用 touchPlaylist
  /// [generation] 启动时的代次快照，每次 await 后检查是否过期
  Future<void> _loadRemainingSongsById(
    int playlistId,
    PlaylistApi playlistApi,
    int startOffset,
    int total,
    int generation, {
    String sort = 'position',
    String order = 'asc',
    String keyword = '',
  }) async {
    final success = await _queueLoader.loadRemaining(
      generation: generation,
      totalCount: total,
      alreadyLoaded: startOffset,
      fetch: (offset, limit) async {
        final resp = await playlistApi.getPlaylistSongs(
          playlistId,
          limit: limit,
          offset: offset,
          sort: sort,
          order: order,
          keyword: keyword,
        );
        return resp.songs;
      },
      onBatch: (batch) {
        addToPlaylist(batch);
      },
    );
    // 仅当代次未变化时才执行 touchPlaylist，避免对错误的歌单更新时间
    if (success && !_queueLoader.isSuperseded(generation)) {
      ref.read(playlistNotifierProvider.notifier).touchPlaylist(playlistId);
      _savePlaybackState();
    }
  }

  /// 播放全部歌曲（按筛选条件）
  /// 策略：先取第一页（100首）立即开始播放，后台异步加载剩余歌曲
  /// 使用 _loadGeneration 防止竞态：用户切换筛选或清空时自动取消旧的后台加载
  /// [keyword] 搜索关键词（可选）
  /// [type] 歌曲类型筛选（可选）
  /// 返回总歌曲数（-1 表示失败）
  Future<int> playAllSongs({
    String? keyword,
    String? type,
    int startIndex = 0,
  }) async {
    final songsApi = ref.read(songsApiProvider);
    const firstPageLimit = 10;

    debugPrint(
      '[Player] playAllSongs: start, keyword=$keyword, type=$type, startIndex=$startIndex',
    );
    _retryPolicy.recordSuccess();
    try {
      final firstPageResponse = await songsApi.getSongs(
        keyword: keyword,
        type: type,
        limit: firstPageLimit,
        offset: 0,
      );
      final firstPageSongs = firstPageResponse.songs;
      final total = firstPageResponse.total;

      debugPrint(
        '[Player] playAllSongs: firstPage=${firstPageSongs.length}, total=$total',
      );

      if (firstPageSongs.isEmpty) {
        debugPrint('[Player] playAllSongs: no songs found');
        return 0;
      }

      // playPlaylist 内部会递增 _loadGeneration，取消之前的后台加载
      final effectiveStartIndex =
          startIndex == 0 && state.playMode == PlayMode.random
              ? _random.nextInt(firstPageSongs.length)
              : startIndex;
      final safeStartIndex = effectiveStartIndex.clamp(
        0,
        firstPageSongs.length - 1,
      );
      await playPlaylist(firstPageSongs, startIndex: safeStartIndex);

      if (total > firstPageSongs.length) {
        // 记录当前代次，传给后台加载任务用于检测是否过期
        final generation = _loadGeneration;
        debugPrint(
          '[Player] playAllSongs: starting background load, generation=$generation, offset=${firstPageSongs.length}',
        );
        _loadRemainingSongsByFilter(
          songsApi,
          keyword,
          type,
          firstPageSongs.length,
          total,
          generation,
        );
      } else {
        debugPrint('[Player] playAllSongs: all songs loaded in first page');
      }

      return total;
    } catch (e, st) {
      debugPrint('[Player] playAllSongs error: $e\n$st');
      return -1;
    }
  }

  /// 后台异步加载剩余歌曲（按筛选条件）并追加到播放列表
  /// [generation] 启动时的代次快照，每次 await 后检查是否过期
  /// 可选的分类过滤参数（genre/artist/album/...）用于分类页补齐整个分类队列
  Future<void> _loadRemainingSongsByFilter(
    SongsApi songsApi,
    String? keyword,
    String? type,
    int startOffset,
    int total,
    int generation, {
    String? genre,
    String? artist,
    String? album,
    String? language,
    String? style,
    int? year,
    int? decade,
  }) async {
    final success = await _queueLoader.loadRemaining(
      generation: generation,
      totalCount: total,
      alreadyLoaded: startOffset,
      fetch: (offset, limit) async {
        final resp = await songsApi.getSongs(
          keyword: keyword,
          type: type,
          genre: genre,
          artist: artist,
          album: album,
          language: language,
          style: style,
          year: year,
          decade: decade,
          limit: limit,
          offset: offset,
        );
        return resp.songs;
      },
      onBatch: (batch) {
        addToPlaylist(batch);
      },
    );
    if (success && !_queueLoader.isSuperseded(generation)) {
      _savePlaybackState();
    }
  }

  /// 后台加载剩余歌曲追加到当前播放列表（供 library / 分类页点击单曲后补全队列）
  /// 可选分类过滤参数（genre/artist/album/...）用于按分类维度补齐整个队列
  void loadRemainingSongsForCurrentPlaylist({
    String? keyword,
    String? type,
    required int loadedCount,
    required int total,
    String? genre,
    String? artist,
    String? album,
    String? language,
    String? style,
    int? year,
    int? decade,
  }) {
    final songsApi = ref.read(songsApiProvider);
    final generation = _loadGeneration;
    debugPrint(
      '[Player] loadRemainingSongsForCurrentPlaylist: offset=$loadedCount, total=$total, generation=$generation',
    );
    _loadRemainingSongsByFilter(
      songsApi,
      keyword,
      type,
      loadedCount,
      total,
      generation,
      genre: genre,
      artist: artist,
      album: album,
      language: language,
      style: style,
      year: year,
      decade: decade,
    );
  }

  /// 切换全屏播放器
  void toggleFullPlayer() {
    state = state.copyWith(showFullPlayer: !state.showFullPlayer);
  }

  /// 关闭全屏播放器
  void closeFullPlayer() {
    state = state.copyWith(showFullPlayer: false);
  }

  /// 切换播放列表抽屉
  void togglePlaylistDrawer() {
    state = state.copyWith(showPlaylistDrawer: !state.showPlaylistDrawer);
  }

  /// 关闭播放列表抽屉
  void closePlaylistDrawer() {
    state = state.copyWith(showPlaylistDrawer: false);
  }

  /// 清除错误消息
  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// 设置睡眠定时器：按时长倒计时，到点 pause
  void setSleepTimerByDuration(Duration duration) {
    _sleepTimerLogic.startByDuration(
      duration,
      onExpired: () {
        _audioHandler.pause();
        state = state.copyWith(clearSleepTimer: true);
      },
      onTick: (remaining) {
        state = state.copyWith(
          sleepTimer: SleepTimerStatus(
            mode: SleepTimerMode.duration,
            remaining: remaining,
          ),
        );
      },
    );
    state = state.copyWith(
      sleepTimer: SleepTimerStatus(
        mode: SleepTimerMode.duration,
        remaining: duration,
      ),
    );
  }

  /// 设置睡眠定时器：播完 N 首歌曲后 pause（含当前正在播放的曲）
  void setSleepTimerAfterSongs(int songs) {
    if (songs < 1) return;
    _sleepTimerLogic.startAfterSongs(songs);
    state = state.copyWith(
      sleepTimer: SleepTimerStatus(
        mode: SleepTimerMode.afterSongs,
        remainingSongs: songs,
      ),
    );
  }

  /// 取消睡眠定时器
  void cancelSleepTimer() {
    _sleepTimerLogic.cancel();
    state = state.copyWith(clearSleepTimer: true);
  }

  /// 播放指定索引
  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= state.playlist.length) return;

    _playbackResumeState.clear();

    // 取消之前的预加载
    _prefetchCancelToken?.cancel('operation changed');

    // 自增播放代次。旧 _playCurrent 协程在下一次 await 后会发现 gen 变化并退出，
    // 不会再用旧歌的 source 覆盖新歌的 setAudioSource。
    final gen = ++_playGeneration;

    _modeResolver.markPlayed(index);
    state = state.copyWith(
      currentIndex: index,
      currentSong: state.playlist[index],
      currentTime: Duration.zero,
    );
    _updateNotificationFavorite();

    await _playCurrent(gen);
    if (gen != _playGeneration) return; // 已被新切歌取代，savePlaybackState 也跳过
    _savePlaybackState();
  }

  /// 当前协程是否已被新一次切歌取代。
  bool _isSuperseded(int gen, String where) {
    if (gen == _playGeneration) return false;
    debugPrint(
      '[Player] _playCurrent superseded at $where: gen=$gen current=$_playGeneration',
    );
    return true;
  }

  Future<bool> _getVolumeNormalizeEnabled() async {
    final current = ref.read(volumeNormalizeProvider).value;
    if (current != null) return current.enabled;

    try {
      return (await ref.read(volumeNormalizeProvider.future)).enabled;
    } catch (e) {
      debugPrint(
        '[Player] Failed to load volume normalize setting, using false: $e',
      );
      return false;
    }
  }

  /// 播放当前歌曲（带自动重试）
  Future<void> _playCurrent(int gen) async {
    final song = state.currentSong;
    if (song == null) {
      debugPrint('[Player] _playCurrent: no current song');
      return;
    }

    final previousSong = _lastPlayedSong;
    _lastPlayedSong = song;
    if (previousSong != null &&
        previousSong.id != song.id &&
        _audioHandler.processingState != ja.ProcessingState.completed) {
      _notifyPlayEvent(previousSong.id, 'skip');
    }

    if (previousSong?.id != song.id) {
      _syncLiveActivitySong(song);
      _syncHomeWidgetSong(song);
    }

    debugPrint(
      '[Player] _playCurrent: ${song.title} (id: ${song.id}, type: ${song.type})',
    );
    debugPrint(
      '[Player] _playCurrent: filePath: ${song.filePath}, url: ${song.url}',
    );

    // 网络歌曲（远程 / 电台）：首播 libmpv 常在慢音源首字节到达前放弃，服务端此时
    // 已在后台全量下载缓存，故用更多次数 + 递增退避重试，等缓存就绪后重试即秒开。
    // 本地歌曲维持原有快速少量重试。
    final isNetworkSong =
        song.type != 'local' && (song.url?.isNotEmpty ?? false);
    final maxRetry = _retryPolicy.maxAttempts(isNetworkSong: isNetworkSong);

    for (int retry = 0; retry <= maxRetry; retry++) {
      if (_isSuperseded(gen, 'retry-loop-top')) return;
      try {
        if (retry > 0) {
          debugPrint('[Player] Retry $retry/$maxRetry for: ${song.title}');
          state = state.copyWith(isRetrying: true);
          // 网络歌曲：首次重试时提示"正在缓存"，让用户知道在等后台缓存而非卡死。
          if (isNetworkSong && retry == 1) {
            state = state.copyWith(infoMessage: l10n.playerCaching);
          }
          final delay = _retryPolicy.delay(
            attempt: retry - 1,
            isNetworkSong: isNetworkSong,
          );
          await Future<void>.delayed(delay);
          if (_isSuperseded(gen, 'retry-delay')) return;
        }

        state = state.copyWith(clearErrorMessage: true);
        // 副作用：刷新 SecureStorageService.cachedAccessToken,供 UrlHelper 使用
        await _secureStorage.getAccessToken();
        if (_isSuperseded(gen, 'after-token')) return;
        // 切歌前清理上一首不完整的 normalize 缓存（songloft-org/songloft-player#35）
        _audioHandler.clearIncompleteNormCache();
        final prefsFuture = ref.read(appPreferencesProvider.future);
        final normalizeFuture = _getVolumeNormalizeEnabled();
        final prefs = await prefsFuture;
        final normalizeOn = await normalizeFuture;
        if (_isSuperseded(gen, 'after-playback-settings')) return;
        final quality = prefs.getAudioQuality();
        debugPrint('[Player] _playCurrent: calling audioHandler.playSong');
        await _audioHandler.playSong(
          song,
          quality: quality,
          normalize: normalizeOn,
        );
        if (_isSuperseded(gen, 'after-playSong')) return;
        _playGenerationAtSource = gen;
        // 移动平台：音量由系统控制，just_audio 固定最大
        // 桌面/Web：使用 just_audio 播放器音量
        if (_useSystemVolume) {
          await _audioHandler.setVolume(1.0);
        } else {
          await _audioHandler.setVolume(state.volume / 100);
        }
        if (_isSuperseded(gen, 'after-volume')) return;
        debugPrint('[Player] _playCurrent: playback started successfully');

        // 播放成功 - 重置连续失败计数
        _retryPolicy.recordSuccess();
        state = state.copyWith(
          isRetrying: false,
          clearInfoMessage: true,
          // 回填播放来源（本地缓存 / 远端流串），供播放页「歌曲信息」展示。
          playbackSource: _audioHandler.lastPlaybackSource,
        );
        _notifyPlayEvent(song.id, 'play', context: state.playbackContext);

        // Only the song restored from the previous app session may consume
        // the saved position. Explicit song and queue changes clear it first.
        final resumePosition = _playbackResumeState.takeFor(
          songId: song.id,
          songType: song.type,
        );
        if (resumePosition != null) {
          await _audioHandler.seek(resumePosition);
          if (_isSuperseded(gen, 'after-seek')) return;
        }

        _startPositionSaveTimer();

        // 预选下一首并预加载
        _prefetchStrategy.onSongChanged();
        _modeResolver.preSelectNext(
          currentIndex: state.currentIndex,
          length: state.playlist.length,
        );
        _prefetchNextSong();
        return; // 成功退出
      } catch (e) {
        debugPrint(
          '[Player] _playCurrent: play failed (retry $retry/$maxRetry): $e',
        );
        if (_isSuperseded(gen, 'after-catch')) return;
      }
    }

    // 所有重试都失败 —— 仍要确认未被取代，避免影响新歌的状态
    if (_isSuperseded(gen, 'all-retries-exhausted')) return;
    debugPrint(
      '[Player] _playCurrent: all retries exhausted for: ${song.title}',
    );
    state = state.copyWith(isRetrying: false, clearInfoMessage: true);
    _handlePlayFailure(gen);
  }

  /// 处理播放失败（重试耗尽后）
  /// 第二层：自动切歌（仅 order/loop/random 模式）
  /// 第三层：连续失败过多则停止
  ///
  /// gen 是触发本次失败的播放代次。若用户已经手动切到新歌，本次失败处理直接放弃，
  /// 避免污染新歌的状态（如把新歌的 errorMessage 覆盖、或自动跳到下下首）。
  void _handlePlayFailure(int gen) {
    if (gen != _playGeneration) {
      debugPrint(
        '[Player] _handlePlayFailure superseded: gen=$gen current=$_playGeneration',
      );
      return;
    }

    final failedSong = state.currentSong?.title ?? l10n.playerUnknownSong;
    final action = _retryPolicy.onAllRetriesExhausted(mode: state.playMode);

    debugPrint(
      '[Player] Song failed after retries: $failedSong, '
      'consecutiveFailures: $_consecutiveFailures, action: $action',
    );

    if (action == FailureAction.stop) {
      if (state.playMode == PlayMode.singlePlay ||
          state.playMode == PlayMode.single) {
        debugPrint('[Player] Single mode, not skipping to next');
        state = state.copyWith(
          isPlaying: false,
          errorMessage: l10n.playerPlayFailedNamed(failedSong),
        );
      } else {
        // 连续失败过多
        debugPrint('[Player] Too many consecutive failures, stopping');
        state = state.copyWith(
          isPlaying: false,
          errorMessage: l10n.playerConsecutiveFailures(_consecutiveFailures),
        );
      }
      _audioHandler.stop();
      return;
    }

    // FailureAction.skipToNext：自动切到下一首（仅 order/loop/random 模式）
    state = state.copyWith(
      errorMessage: l10n.playerPlayFailedTryingNext(failedSong),
    );
    _skipToNextOnFailure();
  }

  /// 播放失败时自动切到下一首
  /// 仅在 order/loop/random 模式下调用
  Future<void> _skipToNextOnFailure() async {
    if (state.playlist.isEmpty || state.playlist.length <= 1) {
      // 只有一首歌或空列表，无法切歌
      state = state.copyWith(
        errorMessage: l10n.playerPlayFailedNoOthers,
        isPlaying: false,
      );
      _audioHandler.stop();
      return;
    }

    int nextIndex;
    if (state.playMode == PlayMode.random) {
      nextIndex =
          _modeResolver.nextIndex(
            currentIndex: state.currentIndex,
            length: state.playlist.length,
          ) ??
          0;
    } else {
      nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.playlist.length) {
        if (state.playMode == PlayMode.order) {
          // 顺序模式已到末尾，停止
          state = state.copyWith(
            errorMessage: l10n.playerPlayFailedEndOfList,
            isPlaying: false,
          );
          _audioHandler.stop();
          return;
        }
        nextIndex = 0; // loop 模式回绕
      }
    }

    debugPrint('[Player] Skipping to next on failure: index $nextIndex');
    await _playAtIndex(nextIndex);
  }

  /// 预拉取下一首歌曲
  void _prefetchNextSong() async {
    final decision = _prefetchStrategy.evaluateAfterPlay(
      playlist: state.playlist,
      currentIndex: state.currentIndex,
      preSelectedNextIndex: _modeResolver.preSelectedIndex,
      playMode: _modeResolver.mode,
    );

    if (!decision.shouldPrefetch || decision.songToPrefetch == null) return;

    final nextSong = decision.songToPrefetch!;

    // 取消之前的预加载
    _prefetchCancelToken?.cancel('new prefetch');
    _prefetchCancelToken = CancelToken();

    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final quality = prefs.getAudioQuality();
      final normalizeOn = await _getVolumeNormalizeEnabled();
      final targetFormat = AudioFormatHelper.getTranscodeFormat(
        nextSong.format,
      );

      final songUrl = UrlHelper.buildSongUrl(
        nextSong.url!,
        songFormat: nextSong.format,
        quality: quality,
        normalize: normalizeOn,
      );
      final separator = songUrl.contains('?') ? '&' : '?';
      final prefetchUrl = '$songUrl${separator}prefetch=1';

      debugPrint(
        '[Player] Prefetching next song: ${nextSong.title} '
        '(type=${nextSong.type}, format=${nextSong.format}, target=$targetFormat)',
      );

      // 后端 ?prefetch=1 会同步返回 202，异步跳起缓存/转码。
      // 客户端不需要下载 body，超时设得短一点即可。
      final dio = Dio();
      final resp = await dio.get<void>(
        prefetchUrl,
        cancelToken: _prefetchCancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          // 202 为预期响应，其他 2xx/3xx 也允许（兼容老后端）
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      debugPrint(
        '[Player] Prefetch ack ${resp.statusCode} for: ${nextSong.title}',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[Player] Prefetch cancelled for: ${nextSong.title}');
      } else {
        debugPrint('[Player] Prefetch failed for: ${nextSong.title}: $e');
      }
    } catch (e) {
      debugPrint('[Player] Prefetch error: $e');
    }
  }

  /// 当前歌曲剩余时间 ≤ 30s 时保险触发一次下一首预拉取。
  /// PrefetchToCache + ffmpeg inflight 都自带去重，重复调用是安全的。
  void _maybeFireLateStagePrefetch(Duration position) {
    final decision = _prefetchStrategy.evaluateLateStagePrefetch(
      currentPosition: position,
      duration: state.duration,
      playlist: state.playlist,
      currentIndex: state.currentIndex,
      preSelectedNextIndex: _modeResolver.preSelectedIndex,
      playMode: _modeResolver.mode,
    );

    if (!decision.shouldPrefetch) return;

    debugPrint('[Player] late-stage prefetch trigger');
    _prefetchNextSong();
  }
}

/// 便捷 Provider：当前是否有歌曲
final hasCurrentSongProvider = Provider<bool>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.hasSong;
});

/// 便捷 Provider：当前是否正在播放
final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.isPlaying;
});

/// 便捷 Provider：当前歌曲
final currentSongProvider = Provider<Song?>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.currentSong;
});

/// 便捷 Provider：播放进度
final playerProgressProvider = Provider<double>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.progress;
});

/// 便捷 Provider：当前播放队列的来源歌单 ID
final sourcePlaylistIdProvider = Provider<int?>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.sourcePlaylistId;
});

/// 视频界面字幕开关（会话内）：默认开启，控制歌词是否以字幕形式叠加在画面上。
/// 仅影响视频/MV 播放界面，与音乐界面的歌词页无关。
class SubtitleEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final subtitleEnabledProvider = NotifierProvider<SubtitleEnabledNotifier, bool>(
  SubtitleEnabledNotifier.new,
);
