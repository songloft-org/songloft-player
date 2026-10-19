import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/audio/audio_service.dart';
import 'package:songloft_flutter/core/audio/live_stream_headers.dart';
import 'package:songloft_flutter/core/audio/songloft_mediakit_player.dart';
import 'package:songloft_flutter/shared/models/song.dart';

/// 只为构造 handler 的最小假播放器：本组测试不触发任何播放调用。
class _NoopPlayer implements ja.AudioPlayer {
  @override
  final Stream<ja.PlaybackEvent> playbackEventStream =
      const Stream<ja.PlaybackEvent>.empty();
  @override
  final Stream<ja.ProcessingState> processingStateStream =
      const Stream<ja.ProcessingState>.empty();
  @override
  final Stream<bool> playingStream = const Stream<bool>.empty();
  @override
  bool playing = false;
  @override
  ja.ProcessingState processingState = ja.ProcessingState.idle;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  double get speed => 1;
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song _liveSong() => Song(
  id: 58,
  type: 'radio',
  title: '经济之声',
  duration: 0,
  url: '/api/v1/songs/58/play',
  sourceUrl: 'http://radio.example/live/index.m3u8',
  isLive: true,
  addedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('handler 构造桌面直播源', () {
    late SongloftAudioHandler handler;
    late TargetPlatform originalPlatform;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      originalPlatform = defaultTargetPlatform;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      handler = SongloftAudioHandler(player: _NoopPlayer());
      await handler.ensureInitialized();
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = originalPlatform;
      await handler.dispose();
    });

    test('桌面 live：headers 为 null，UA/Referer 进 tag', () {
      final headers = handler.buildLiveStreamHeadersForTest(_liveSong());
      expect(headers, isNotNull);
      expect(headers!['Referer'], 'http://radio.example/');
      expect(headers['User-Agent'], contains('Songloft'));

      final source = handler.buildLiveSourceForTest(
        songUrl:
            'http://10.0.0.2:8091/api/v1/songs/58/play.m3u8'
            '?access_token=t&hls=direct',
        liveHeaders: headers,
        isDesktopLive: true,
      );

      expect(source.headers, isNull);
      expect(source.tag, isA<LiveStreamHeaders>());
      expect(
        (source.tag as LiveStreamHeaders).values,
        headers,
        reason: '防盗链头必须仍随源传给原生播放器',
      );
    });

    test('非桌面 live：请求头仍走 headers（保持入参语义不变）', () {
      final headers = <String, String>{'Accept': '*/*'};
      final source = handler.buildLiveSourceForTest(
        songUrl: 'http://10.0.0.2:8091/api/v1/songs/58/play.m3u8',
        liveHeaders: headers,
        isDesktopLive: false,
      );
      expect(source.headers, isNotNull);
      expect(source.tag, isNull);
    });

    test('桌面普通歌曲不属于直播头路径', () {
      final song = Song(
        id: 1,
        type: 'local',
        title: '普通歌',
        duration: 10,
        url: '/api/v1/songs/1/play',
        addedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(handler.buildLiveStreamHeadersForTest(song), isNull);
    });
  });

  group('桌面直播请求头不进 just_audio headers（绕开回环代理）', () {
    test('桌面直播：headers 为空，请求头挂在 tag 上', () {
      // 这里直接构造 just_audio 源并检查其字段，等价于 _buildLiveSource 的产物：
      // 只要 headers 非空，just_audio 的 UriAudioSource._onLoad 就会启用本机代理，
      // 而该代理的 m3u8 子资源 key 用入口 URL 的 query 拼，与切片实际 query 不符。
      const tag = LiveStreamHeaders({
        'User-Agent': 'Songloft',
        'Referer': 'http://radio.example/',
      });
      final source = ja.AudioSource.uri(
        Uri.parse(
          'http://10.0.0.2:8091/api/v1/songs/58/play.m3u8'
          '?access_token=t&hls=direct',
        ),
        tag: tag,
      );

      expect(source.headers, isNull, reason: 'headers 非空会触发 just_audio 回环代理');
      expect(source.tag, same(tag));
      expect(source.tag.values['Referer'], 'http://radio.example/');
    });

    test('非桌面直播保留原 headers 行为（insecureTls 占位头依赖代理）', () {
      final headers = <String, String>{'Accept': '*/*', 'Icy-MetaData': '1'};
      final source = ja.AudioSource.uri(
        Uri.parse('http://10.0.0.2:8091/api/v1/songs/1/play.m3u8'),
        headers: headers,
      );
      expect(source.headers, headers);
      expect(source.tag, isNull);
    });
  });

  group('LiveStreamHeaders 语义', () {
    test('值相等即相等（便于 tag 比较与调试日志）', () {
      const a = LiveStreamHeaders({'User-Agent': 'UA', 'Referer': 'R'});
      const b = LiveStreamHeaders({'Referer': 'R', 'User-Agent': 'UA'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('值不同则不等', () {
      const a = LiveStreamHeaders({'Referer': 'R1'});
      const b = LiveStreamHeaders({'Referer': 'R2'});
      expect(a, isNot(b));
    });
  });

  group('SongloftMediaKitPlayer 把 tag 中的请求头交给 libmpv', () {
    test('tag 为 LiveStreamHeaders 时转成 Media.httpHeaders', () {
      final media = SongloftMediaKitPlayer.convertAudioSourceForTest(
        HlsAudioSourceMessage(
          id: 'hls-1',
          uri:
              'http://10.0.0.2:8091/api/v1/songs/58/play.m3u8'
              '?access_token=t&hls=direct',
          tag: const LiveStreamHeaders({
            'User-Agent': 'Songloft',
            'Referer': 'http://radio.example/',
            'Icy-MetaData': '1',
          }),
        ),
      );

      // media_kit 会把 httpHeaders 设置到 mpv 的 http-header-fields，
      // 因此这里非空就说明防盗链头仍能到达源站。
      expect(media.httpHeaders, {
        'User-Agent': 'Songloft',
        'Referer': 'http://radio.example/',
        'Icy-MetaData': '1',
      });
    });

    test('普通 headers 仍优先（保持既有行为）', () {
      final media = SongloftMediaKitPlayer.convertAudioSourceForTest(
        ProgressiveAudioSourceMessage(
          id: 'p-1',
          uri: 'http://host/a.mp3',
          headers: {'Accept': '*/*'},
          tag: const LiveStreamHeaders({'Referer': 'R'}),
        ),
      );
      expect(media.httpHeaders, {'Accept': '*/*'});
    });

    test('无 tag 无 headers 时只用该 URL 自身的头（不串用同 URL 的旧缓存头）', () {
      // media_kit 的 Media 按 URL 缓存 httpHeaders；不同 id 但同 URL 的用例会串味，
      // 故这里用独立 URL，避免测试彼此依赖执行顺序。
      final media = SongloftMediaKitPlayer.convertAudioSourceForTest(
        ProgressiveAudioSourceMessage(
          id: 'p-2',
          uri: 'http://host/untagged.mp3',
        ),
      );
      expect(media.httpHeaders, isNull);
    });
  });
}
