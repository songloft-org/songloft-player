import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/insecure_media_proxy_native.dart';

void main() {
  // 用一个可预测的 wrap：把绝对 URI 编码进本机代理入口，便于断言解析是否正确。
  String wrap(Uri abs) => 'http://127.0.0.1:9/w?u=${Uri.encodeComponent(abs.toString())}';

  final base = Uri.parse('https://self-signed.example/api/v1/songs/5/play.m3u8');

  group('rewriteHlsPlaylist', () {
    test('相对切片行按 base 解析并改写', () {
      const body = '#EXTM3U\n'
          '#EXT-X-VERSION:3\n'
          '#EXTINF:9.0,\n'
          'seg0.ts\n'
          '#EXTINF:9.0,\n'
          'sub/seg1.ts\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(
        out,
        contains('u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/seg0.ts')}'),
      );
      expect(
        out,
        contains('u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/sub/seg1.ts')}'),
      );
      // 标签行保持不变
      expect(out, contains('#EXT-X-VERSION:3'));
      expect(out, contains('#EXTINF:9.0,'));
    });

    test('绝对切片行原样解析并改写', () {
      const body = '#EXTM3U\n'
          'https://cdn.other/live/seg9.ts\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(
        out,
        contains('u=${Uri.encodeComponent('https://cdn.other/live/seg9.ts')}'),
      );
    });

    test('后端 hls-proxy 风格的相对 segment?u= 保留查询串', () {
      const body = '#EXTM3U\n'
          'hls/segment?u=aHR0cHM6Ly9vcmln\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(
        out,
        contains('u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/hls/segment?u=aHR0cHM6Ly9vcmln')}'),
      );
    });

    test('EXT-X-KEY 的 URI 属性被改写', () {
      const body = '#EXTM3U\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="keys/k1.key",IV=0x1234\n'
          '#EXTINF:9.0,\n'
          'seg0.ts\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(
        out,
        contains('URI="http://127.0.0.1:9/w?u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/keys/k1.key')}"'),
      );
      // METHOD / IV 等其它属性保持不变
      expect(out, contains('METHOD=AES-128'));
      expect(out, contains('IV=0x1234'));
    });

    test('EXT-X-MAP 与变体播放列表 URI 被改写', () {
      const body = '#EXTM3U\n'
          '#EXT-X-MAP:URI="init.mp4"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
          '720p.m3u8\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(
        out,
        contains('URI="http://127.0.0.1:9/w?u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/init.mp4')}"'),
      );
      expect(
        out,
        contains('u=${Uri.encodeComponent('https://self-signed.example/api/v1/songs/5/720p.m3u8')}'),
      );
    });

    test('保留 CRLF 行尾与空行', () {
      const body = '#EXTM3U\r\n#EXTINF:9.0,\r\nseg0.ts\r\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(out, contains('#EXTM3U\r\n'));
      expect(out, contains('\r\n'));
      // 末行处理不额外追加换行
      expect(out.endsWith('\r\n'), isTrue);
    });

    test('空 URI 属性不被改写', () {
      const body = '#EXTM3U\n#EXT-X-KEY:METHOD=NONE\n#EXTINF:9,\nseg0.ts\n';
      final out = rewriteHlsPlaylist(body, base, wrap);
      expect(out, contains('#EXT-X-KEY:METHOD=NONE'));
    });
  });
}
