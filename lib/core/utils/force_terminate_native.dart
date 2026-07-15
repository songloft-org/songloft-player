import 'dart:ffi';
import 'dart:io';

// kernel32!GetCurrentProcess() -> HANDLE（伪句柄，恒为 (HANDLE)-1）
typedef _GetCurrentProcessC = IntPtr Function();
typedef _GetCurrentProcessDart = int Function();

// kernel32!TerminateProcess(HANDLE hProcess, UINT uExitCode) -> BOOL
typedef _TerminateProcessC = Int32 Function(IntPtr hProcess, Uint32 uExitCode);
typedef _TerminateProcessDart = int Function(int hProcess, int uExitCode);

/// 强制终止当前进程。
///
/// Windows：调用 `TerminateProcess(GetCurrentProcess(), code)` 内核级硬杀。
/// 与 `dart:io` 的 `exit()`（会跑 C runtime atexit/静态析构）不同，
/// `TerminateProcess` 立即回收进程及其所有线程，**不运行任何析构或线程 teardown**，
/// 因此 media_kit 延迟销毁 libmpv 的后台线程根本没机会执行 `__fastfail`，
/// 从根本上消除退出报警框（songloft-org/songloft#271）。
///
/// 其他原生平台（Linux/macOS/Android/iOS）无此问题，退回普通 `exit()`。
void forceTerminateProcess(int code) {
  if (!Platform.isWindows) {
    exit(code);
  }

  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getCurrentProcess = kernel32
      .lookupFunction<_GetCurrentProcessC, _GetCurrentProcessDart>(
        'GetCurrentProcess',
      );
  final terminateProcess = kernel32
      .lookupFunction<_TerminateProcessC, _TerminateProcessDart>(
        'TerminateProcess',
      );
  terminateProcess(getCurrentProcess(), code);

  // 理论上不会返回；兜底退回普通 exit。
  exit(code);
}
