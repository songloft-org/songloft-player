// WebGL context 丢失/恢复时清空 imageCache，修复回滚封面不显示（仅 Web 生效）。
//
// 条件导入：web 走 `_impl`（真实注册 DOM 事件监听），原生平台走 `_stub`（no-op）。
export 'webgl_context_recovery_impl.dart'
    if (dart.library.io) 'webgl_context_recovery_stub.dart';
