/// 非 Web 平台的 no-op 实现:原生端不存在 WebGL context 丢失问题。
///
/// 返回检测到「context 已丢失」的画布数量,原生端恒为 0。
int reportLostWebGlContexts() => 0;
