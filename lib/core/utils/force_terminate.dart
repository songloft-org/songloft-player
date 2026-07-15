// 强制终止当前进程。
//
// Web 平台不支持进程退出（stub 为 no-op）；原生平台见 force_terminate_native.dart。
// Windows 上走 TerminateProcess 内核级硬杀，避免 libmpv 后台销毁线程在
// 进程 teardown 时触发 Fail Fast 报警框（songloft-org/songloft#271）。
export 'force_terminate_stub.dart'
    if (dart.library.io) 'force_terminate_native.dart';
