import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class TracelyClient {
  final String appId;
  final String appSecret;
  final String host;
  final Dio _dio;

  TracelyClient({
    required this.appId,
    required this.appSecret,
    required this.host,
  }) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'Content-Type': 'application/json'},
        ));

  Map<String, String> _buildHeaders() {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _generateNonce();
    final message = utf8.encode('$appId$timestamp$nonce');
    final key = utf8.encode(appSecret);
    final hmacSha256 = Hmac(sha256, key);
    final signature = hmacSha256.convert(message).toString();
    return {
      'X-App-Id': appId,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
    };
  }

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> reportEvent(
      String eventName, Map<String, dynamic> metadata, String userId) async {
    try {
      await _dio.post(
        '$host/report/event',
        data: {
          'eventName': eventName,
          'metadata': metadata,
          'appId': appId,
          'userId': userId,
        },
        options: Options(headers: _buildHeaders()),
      );
    } catch (_) {}
  }

  Future<void> reportError({
    required String type,
    required String message,
    String? stack,
  }) async {
    try {
      await _dio.post(
        '$host/report/error',
        data: {
          'type': type,
          'message': message,
          'stack': stack ?? '',
          'url': '',
          'appId': appId,
        },
        options: Options(headers: _buildHeaders()),
      );
    } catch (_) {}
  }

  Future<void> reportInstall(
      String version, String platform, String userId) async {
    await reportEvent(
        '_app_install', {'version': version, 'platform': platform}, userId);
  }

  Future<void> reportUpgrade(String fromVersion, String toVersion,
      String platform, String userId) async {
    await reportEvent(
      '_app_upgrade',
      {
        'version': toVersion,
        'from_version': fromVersion,
        'to_version': toVersion,
        'platform': platform,
      },
      userId,
    );
  }
}
