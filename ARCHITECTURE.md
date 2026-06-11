# 项目架构分析

## 模块依赖关系图
UI Layer (Widgets) -> Presentation (Riverpod Providers) -> Domain (UseCases/Logic) -> Data (Repositories/Network) -> Core (Services/Infra) -> Native/Plugins

## 核心功能流
- **初始化流**: main.dart -> WindowSingleInstance / MediaKit 初始化 -> 获取授权 Token 缓存 -> AudioService 初始化 -> 启动 ProviderScope App
- **播放控制流**: UI 操作 -> Player Providers -> AudioService -> just_audio_media_kit -> libmpv / native player

## 架构模式
- **分层架构 (Layered Architecture)**: 按 Feature 划分业务，每个 Feature 内部采用 Clean Architecture 变体 (data / domain / presentation)
- **状态驱动**: 基于 Riverpod 实现单向数据流和依赖注入

## 模块接口与通信方式
- **内部通信**: 通过 Riverpod (`ref.read` / `ref.watch`) 进行状态订阅与分发
- **外部/平台通信**: Flutter MethodChannels 桥接原生系统，Dio 用于网络 HTTP 请求

## 关键模块标记
- android: contains Kotlin source files
- assets: contains submodules or grouped resources
- fonts: contains project files

