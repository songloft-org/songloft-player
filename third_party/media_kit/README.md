# media_kit 本地初始化补丁

[English](README.en.md)

来源：pub.dev 的 `media_kit 1.2.6`，上游为 <https://github.com/media-kit/media-kit>，保留 MIT `LICENSE`。仅纳入运行所需的 `lib/`、`assets/`、包清单及许可证；截图和示例不纳入，包清单的截图声明相应移除。

客户端通过 `pubspec.yaml` 的 `dependency_overrides.media_kit.path` 引用本目录。不要修改全局 pub 缓存；CI、标准版和 Bundle 版都应解析到这份源码。

## 补丁范围

关联：<https://github.com/songloft-org/songloft-player/issues/49>。

- `lib/src/player/native/core/mpv_initialization.dart`：创建后判空，检查 `mpv_initialize()` 返回值，失败时释放已创建的 context；诊断包含失败的 API 和 libmpv 错误信息。
- `initializer_native_callable.dart`、`initializer_isolate.dart`：共用上述初始化逻辑；回调注册失败时清理 context 与回调；isolate 将失败信息及堆栈传回调用方，关闭失败 worker，并在 worker 创建失败时关闭接收端口。
  事件回调异常按 isolate 路径的方式记录，避免初始化失败后已排队的事件产生未处理的 Future 异常。
- `lib/src/player/native/player/real.dart`：将初始化异常传到 `waitForPlayerInitialization`，避免未处理的 Future 异常；创建失败后可以关闭 Dart 侧资源，无需调用 NULL context；context 创建成功但后续配置失败时，同样移除回调并释放原生资源。

Linux 的 `LC_NUMERIC=C` 修复在应用的 `linux/runner/` 中，客户端的异常转换及失败实例清理在 `lib/core/audio/` 中。

## 验证与升级

在客户端根目录执行：

```bash
flutter pub get
flutter test test/core/audio/mpv_initialization_test.dart
flutter analyze
```

测试在 Linux 用 GCC 构建故障注入共享库，直接经 Dart FFI 验证两条初始化路径的 NULL、初始化失败、成功、清理和客户端重试，不依赖音频设备。

安装 GTK/libmpv 开发包、CMake、Xvfb、`xvfb-run` 和 xauth 后，可验证真实库的 locale 修复与音频解码（`ao=null` 无需音频设备）：

```bash
cmake -S test/native/linux -B /tmp/songloft-mpv-locale
cmake --build /tmp/songloft-mpv-locale
ctest --test-dir /tmp/songloft-mpv-locale -V
```

测试覆盖 C、C.UTF-8、en_US.UTF-8 和 zh_CN.UTF-8。使用 glibc 的系统须先安装或生成上述 locale，确保实际测试非 C locale。

升级上游版本时，对照 pub.dev 的原始包逐文件审查上述补丁，保留许可证和 Web assets，并重新运行验证。上游合入完整修复后可以删除本地依赖覆盖；Linux locale 修复仍需保留。不要只加判空而遗漏 isolate 错误传递及等待初始化的 Future。
