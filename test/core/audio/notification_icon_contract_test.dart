import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 通知栏 / 媒体控件图标的资源契约（songloft-org/songloft#329）。
///
/// Dart 侧 `MediaControl(androidIcon: 'drawable/xxx')` 引用的是**原生资源**，而安卓热更只
/// 换 libapp.so，`res/` 永远随旧 APK 冻结。两类写法会让整条媒体通知不显示、前台服务建不
/// 起来（表现为「通知栏播放器看不到 + 播放一会就停」，且 Dart 日志毫无痕迹）：
///
///   1. 资源在宿主 APK 里不存在 → `getIdentifier()` 返回 0 →
///      `PlaybackStateCompat.CustomAction.Builder` 抛 IllegalArgumentException。
///   2. 资源里引用了应用主题属性（`?attr/...`）→ 图标由 SystemUI 在它自己的上下文渲染，
///      解析不到该属性 → `Resources$NotFoundException`。
///
/// 本测试静态校验第 2 类（第 1 类要真机比对 APK，只能靠"复用早已存在的资源 + 不改名"的
/// 约定，见 audio_service.dart 里 _favoriteControl 上方注释）。
///
/// 例外：`audio_service_*` 前缀的资源来自 audio_service 包的 AAR，由 Gradle 合并进
/// APK，不在本仓库 res/ 下——跳过本地文件检查。
void main() {
  test('audio_service.dart 引用的 androidIcon 资源存在且不含 ?attr 主题引用', () {
    final source = File('lib/core/audio/audio_service.dart').readAsStringSync();
    final refs =
        RegExp(r"androidIcon:\s*'(drawable|mipmap)/([A-Za-z0-9_]+)'")
            .allMatches(source)
            .map((m) => (type: m.group(1)!, name: m.group(2)!))
            .toSet();

    expect(refs, isNotEmpty, reason: '正则没匹配到 androidIcon，改了写法就同步改这个测试');

    for (final ref in refs) {
      // audio_service_* 资源来自 audio_service 包 AAR，Gradle 合并时自动打入 APK，
      // 不在本仓库 res/ 下，跳过本地文件检查。
      if (ref.name.startsWith('audio_service_')) continue;

      final candidates =
          Directory('android/app/src/main/res')
              .listSync()
              .whereType<Directory>()
              .where((d) => d.path.split('/').last.startsWith(ref.type))
              .expand((d) => d.listSync().whereType<File>())
              .where((f) {
                final base = f.path.split('/').last;
                return base == '${ref.name}.xml' ||
                    base.startsWith('${ref.name}.');
              })
              .toList();

      expect(
        candidates,
        isNotEmpty,
        reason:
            '${ref.type}/${ref.name} 在 android/app/src/main/res 下找不到。通知图标必须是'
            '本仓库里真实存在、且早已随历史 APK 落地的资源（res/ 不能热更）',
      );

      for (final file in candidates) {
        if (!file.path.endsWith('.xml')) continue;
        final markup = file.readAsStringSync().replaceAll(
          RegExp(r'<!--.*?-->', dotAll: true),
          '',
        );
        expect(
          markup,
          isNot(contains('?attr/')),
          reason:
              '${file.path} 含 ?attr/ 主题属性引用：SystemUI 渲染通知图标时解析不到应用'
              '主题，会抛 Resources\$NotFoundException 使整条媒体通知不显示',
        );
      }
    }
  });
}
