import 'package:flutter/services.dart';

class TvDetector {
  static const MethodChannel _channel = MethodChannel('com.songloft/tv_detector');

  static Future<bool> isTv() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isTvMode');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
