# HARNESS

## 项目类型
Flutter 跨平台应用 (主打 Windows 桌面端)

## 构建命令
`flutter build windows`

## 编译启动诊断
- **WorkingDirectory**: `D:\Code\github\songloft\songloft-player`
- **RecommendedTerminal**: PowerShell (Windows) 或 Bash
- **CanRunBuildHere**: yes
- **MissingCommands**: build 命令缺失，不能启动编译
- **FailureEvidence**: 记录完整命令、工作目录、终端类型、退出码、前 50 行和最后 100 行构建日志

## 快速验证命令
`flutter run -d windows`

## Bugfix 验证命令
`flutter test` 或启动特定平台验证 (`flutter run -d windows`)

## 完整验证命令
`flutter clean && flutter pub get && dart run build_runner build -d && flutter build windows`

## 高风险目录
- `windows/runner/`: C++ 原生桥接层和 Win32 初始化，可能涉及非托管内存
- `lib/core/audio/`: 音频播放控制核心层，异常可能导致全局服务崩溃

## 禁改区域
- .git: version control metadata

## 自动识别候选
- `windows/runner/flutter_window.cpp`: 检测到 Win32 API 使用
- `windows/runner/flutter_window.h`: 检测到 Win32 API 使用
- `windows/runner/main.cpp`: 检测到 Win32 API 使用
- `windows/runner/utils.cpp`: 检测到 Win32 API 使用
- `windows/runner/win32_window.cpp`: 检测到 Win32 API 使用
- `windows/runner/win32_window.h`: 检测到 Win32 API 使用

## 需人工确认
- `bugfix` 验证命令仍缺失，需人工补齐可信入口
- build / quick / full 命令映射不完整，需人工确认最终入口
- `windows/runner/flutter_window.cpp` 是否允许 AI 直接修改，需人工确认

