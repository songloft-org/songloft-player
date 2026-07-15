/// Web 平台占位：浏览器无进程可终止，直接 no-op。
///
/// 该路径只会在 Windows 退出流程被调用（见 main.dart），Web 不会触达。
void forceTerminateProcess(int code) {
  // no-op on web
}
