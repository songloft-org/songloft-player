import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/server_redirect_resolver.dart';

void main() {
  group('ServerRedirectResolver.deriveBase', () {
    test('剥离末尾 /api/v1/health，保留 scheme+host+随机端口', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://song.ipv4.123.xyz:54321/api/v1/health'),
      );
      expect(base, 'https://song.ipv4.123.xyz:54321');
    });

    test('固定端口 IPv6 直连场景', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://song.ipv6.123.xyz:8899/api/v1/health'),
      );
      expect(base, 'https://song.ipv6.123.xyz:8899');
    });

    test('无端口时不追加端口', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://song.example.com/api/v1/health'),
      );
      expect(base, 'https://song.example.com');
    });

    test('子路径部署：保留 basePath 前缀', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://host.example.com:9000/music/api/v1/health'),
      );
      expect(base, 'https://host.example.com:9000/music');
    });

    test('带 query 的最终 URL 不影响 base 推导', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://real.example.com:12345/api/v1/health?x=1'),
      );
      expect(base, 'https://real.example.com:12345');
    });

    test('未以 /api/v1/health 结尾时退回 origin（去掉多余路径）', () {
      final base = ServerRedirectResolver.deriveBase(
        Uri.parse('https://real.example.com:12345/some/other'),
      );
      expect(base, 'https://real.example.com:12345');
    });

    test('无 host 返回空串（由调用方降级为入口域名）', () {
      final base = ServerRedirectResolver.deriveBase(Uri.parse('/api/v1/health'));
      expect(base, '');
    });
  });

  group('ServerRedirectResolver.resolve', () {
    test('空入口 URL 原样返回', () async {
      expect(await ServerRedirectResolver.resolve(''), '');
    });
  });
}
