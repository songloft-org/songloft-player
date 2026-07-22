import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 原生：把 zip 写入临时目录，再按路径构造 XFile 分享（多数平台需真实文件路径）。
Future<XFile> buildLogShareFile(Uint8List bytes, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final path = '${tempDir.path}${Platform.pathSeparator}$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes);
  return XFile(path, name: fileName, mimeType: 'application/zip');
}
