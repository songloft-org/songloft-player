import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Web：直接用字节构造 XFile 分享，无需文件系统。
Future<XFile> buildLogShareFile(Uint8List bytes, String fileName) async {
  return XFile.fromData(bytes, name: fileName, mimeType: 'application/zip');
}
