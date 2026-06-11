import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:songloft_flutter/core/env/tv_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.songloft/tv_detector');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isTv returns true when method channel returns true', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'isTvMode') {
        return true;
      }
      return null;
    });

    final isTv = await TvDetector.isTv();
    expect(isTv, isTrue);
  });

  test('isTv returns false when method channel returns false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'isTvMode') {
        return false;
      }
      return null;
    });

    final isTv = await TvDetector.isTv();
    expect(isTv, isFalse);
  });

  test('isTv returns false on MissingPluginException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw MissingPluginException();
    });

    final isTv = await TvDetector.isTv();
    expect(isTv, isFalse);
  });
}
