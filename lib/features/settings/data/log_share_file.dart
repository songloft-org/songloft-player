// 按平台构造分享用的日志 zip 文件：Web 用字节，原生写临时文件后按路径分享。
// 通过条件导入避免在 Web 构建中引入 dart:io。
export 'log_share_file_stub.dart'
    if (dart.library.io) 'log_share_file_io.dart';
