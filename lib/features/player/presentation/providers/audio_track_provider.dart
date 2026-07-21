import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../core/audio/audio_backend.dart';
import '../../../../core/audio/songloft_just_audio_platform.dart';
import '../../../../core/utils/audio_format_helper.dart';
import '../../../../main.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../library/data/songs_api.dart';
import '../../../library/presentation/providers/songs_provider.dart';
import 'player_provider.dart';

/// 音轨切换状态（songloft-org/songloft#297、#298）。
///
/// - **原生平台**（Android/iOS/桌面，均走 media_kit/libmpv）：数据来源是底层 [Player] 的
///   `state.tracks.audio` / `state.track.audio`，切轨由 libmpv 原生完成、即时生效。
/// - **Web**（浏览器不认 Matroska 容器、无多轨枚举/切换 API）：音轨列表来自后端
///   `GET /songs/{id}/audio-tracks`（ffprobe 探测），切轨通过重建播放 URL（`?track=N`）
///   让后端抽轨（AAC 无损 remux 成 m4a）+ 无缝重载并 seek 回原进度实现。
@immutable
class AudioTrackState {
  /// 可选择的真实音轨列表（原生端已剔除 libmpv 的 `auto` / `no` 伪音轨；Web 端为后端返回的音频流）。
  final List<AudioTrack> tracks;

  /// 当前选中的音轨（原生端可能是 `auto` 伪音轨，表示由 libmpv 自动选默认轨；Web 端为当前抽取的音轨）。
  final AudioTrack? selected;

  const AudioTrackState({this.tracks = const [], this.selected});

  /// 是否为多音轨（>1 时才展示音轨切换入口）。
  bool get hasMultiple => tracks.length > 1;

  /// 判断某条真实音轨是否为当前正在输出的音轨。
  /// selected 为 `auto` 时，对应 libmpv 实际选择的默认轨（isDefault）或首条。
  bool isCurrent(AudioTrack track) {
    final sel = selected;
    if (sel == null) return false;
    if (sel.id == track.id) return true;
    if (sel.id == 'auto') {
      final defaultTrack = tracks.firstWhere(
        (t) => t.isDefault == true,
        orElse: () => tracks.isNotEmpty ? tracks.first : track,
      );
      return defaultTrack.id == track.id;
    }
    return false;
  }
}

/// 音轨状态 Notifier：原生端桥接 media_kit [Player] 的音轨流；Web 端拉取后端音轨列表。
///
/// 原生端：libmpv 打开媒体后异步探测出 track-list，通过 `stream.tracks` 推送；用户切轨或默认轨
/// 选定通过 `stream.track` 推送。本 Notifier 订阅这两条流并映射为 [AudioTrackState]。
/// Web 端：切歌时（[build] watch [currentSongProvider]）若为多音轨容器（mka）则异步拉取
/// `/songs/{id}/audio-tracks`，用 [_webGen] 守卫避免旧请求覆盖新歌的状态。
class AudioTrackNotifier extends Notifier<AudioTrackState> {
  Player? _boundPlayer;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;

  /// Web 端拉取音轨列表的代次守卫：切歌自增，旧请求返回时若代次已变则丢弃。
  int _webGen = 0;

  @override
  AudioTrackState build() {
    // 切歌时重建以重新绑定音轨流 / 重新拉取 Web 音轨列表。
    final song = ref.watch(currentSongProvider);

    ref.onDispose(() {
      _tracksSub?.cancel();
      _trackSub?.cancel();
      _tracksSub = null;
      _trackSub = null;
      _boundPlayer = null;
      _webGen++; // 使进行中的 Web 拉取失效
    });

    if (kIsWeb) {
      // Web 走独立音频平台，无 media_kit Player：音轨列表来自后端 ffprobe 探测。
      _webGen++;
      final gen = _webGen;
      if (song != null &&
          !song.isVideo &&
          AudioFormatHelper.isWebMultiTrackContainer(song.format)) {
        _fetchWebTracks(song.id, gen);
      }
      // 先返回空，_fetchWebTracks 完成后再 set state。
      return const AudioTrackState();
    }

    // 原生端还需 watch 播放状态：media_kit Player 是懒创建的（首次 setAudioSource 时才存在，
    // 此刻 currentSong 已先行变更、Player 仍为 null，单靠 currentSong 会错过首曲绑定）。
    // 首次开始播放会让 isPlaying 变化 → 重建 → 此时 Player 已就绪，得以建立订阅。
    ref.watch(playerStateProvider.select((s) => s.isPlaying));
    return _bind();
  }

  /// Web：拉取后端音轨列表，构造为 media_kit [AudioTrack]（id = audio-relative index 字符串）。
  /// 默认选中首轨（index 0），与 [SongloftAudioHandler.playSong] 的 Web 默认抽轨（track=0）一致。
  Future<void> _fetchWebTracks(int songId, int gen) async {
    try {
      final infos = await ref.read(songsApiProvider).getAudioTracks(songId);
      if (gen != _webGen) return; // 已切到别的歌
      if (infos.length < 2) {
        state = const AudioTrackState();
        return;
      }
      final tracks = infos.map(_infoToTrack).toList(growable: false);
      // 默认播放首轨（0）；若首轨越界则回退首元素。
      final selected = tracks.isNotEmpty ? tracks.first : null;
      state = AudioTrackState(tracks: tracks, selected: selected);
    } catch (e) {
      if (gen == _webGen) {
        state = const AudioTrackState();
      }
      debugPrint('[AudioTrack] fetch web tracks failed: $e');
    }
  }

  AudioTrack _infoToTrack(AudioTrackInfo info) {
    return AudioTrack(
      info.index.toString(),
      info.title.isEmpty ? null : info.title,
      info.language.isEmpty ? null : info.language,
      isDefault: info.isDefault,
      codec: info.codec.isEmpty ? null : info.codec,
    );
  }

  AudioTrackState _bind() {
    // 非 media_kit 后端（理论上不会到这，Web 已在上面返回）：音轨切换不可用。
    if (!AudioBackend.usesMediaKit) {
      return const AudioTrackState();
    }

    final player = SongloftJustAudioPlatform.instance.firstPlayer;
    if (player == null) {
      // Player 尚未创建（首次播放前）。切歌会重建本 Notifier 再次尝试绑定。
      return const AudioTrackState();
    }

    // 已绑定到同一 Player：保持既有订阅，返回当前快照。
    if (identical(player, _boundPlayer) &&
        _tracksSub != null &&
        _trackSub != null) {
      return _snapshot(player);
    }

    // 绑定到新的 Player 实例：取消旧订阅，重新订阅。
    _tracksSub?.cancel();
    _trackSub?.cancel();
    _boundPlayer = player;

    _tracksSub = player.stream.tracks.listen((_) {
      if (_boundPlayer != null) state = _snapshot(_boundPlayer!);
    });
    _trackSub = player.stream.track.listen((_) {
      if (_boundPlayer != null) state = _snapshot(_boundPlayer!);
    });

    return _snapshot(player);
  }

  AudioTrackState _snapshot(Player player) {
    final real = player.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList(growable: false);
    return AudioTrackState(tracks: real, selected: player.state.track.audio);
  }

  /// 切换到指定音轨。
  /// - 原生端：libmpv 原生切轨即时生效、无需重新加载媒体。
  /// - Web 端：重建播放 URL（`?track=N`）→ 无缝重载并 seek 回原进度 → 恢复播放/暂停状态。
  Future<void> selectTrack(AudioTrack track) async {
    if (kIsWeb) {
      final idx = int.tryParse(track.id);
      if (idx == null) return;
      final song = ref.read(currentSongProvider);
      if (song == null) return;
      final playerState = ref.read(playerStateProvider);
      final handler = ref.read(audioHandlerProvider);
      String? quality;
      try {
        final prefs = await ref.read(appPreferencesProvider.future);
        quality = prefs.getAudioQuality();
      } catch (_) {
        quality = null;
      }
      await handler.switchWebAudioTrack(
        song,
        trackIndex: idx,
        position: playerState.currentTime,
        resumePlaying: playerState.isPlaying,
        quality: quality,
      );
      // 更新选中态（音轨列表不变）。
      state = AudioTrackState(tracks: state.tracks, selected: track);
      return;
    }

    final player = _boundPlayer;
    if (player == null) return;
    await player.setAudioTrack(track);
  }
}

/// 音轨切换状态 Provider（原生 media_kit 平台 + Web 均可用）。
final audioTrackProvider =
    NotifierProvider<AudioTrackNotifier, AudioTrackState>(
  AudioTrackNotifier.new,
);
