import 'dart:convert';

import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/dlna/data/dlna_service.dart';

class _Device extends DLNADevice {
  _Device()
    : super(
        DeviceInfo('http://192.168.2.111:25826', 'MediaRenderer', '电视', [
          {
            'serviceId': 'urn:upnp-org:serviceId:AVTransport',
            'controlURL': '/upnp/service/AVTransport/Control',
          },
        ]),
      );

  final commands = <String>[];
  final failures = <String>{};
  final requests = <String>[];
  final responses = <String, String>{};

  Future<String> send(String action) async {
    commands.add(action);
    if (failures.contains(action)) {
      throw Exception(
        'request http://192.168.2.111:25826/upnp/service/AVTransport/Control '
        'error, status 500 <errorCode>716</errorCode>'
        '<errorDescription>Resource not found</errorDescription> '
        '<res>https://server/play?access_token=private-token&amp;quality=original</res>',
      );
    }
    return responses[action] ?? '';
  }

  @override
  Future<String> request(String action, List<int> body) {
    requests.add(utf8.decode(body));
    return send(action);
  }

  @override
  Future<String> play() => send('Play');

  @override
  Future<String> pause() => send('Pause');

  @override
  Future<String> stop() => send('Stop');
}

class _Manager extends DLNAManager {
  final deviceManager = DeviceManager();

  @override
  Future<DeviceManager> start({reusePort = false}) async => deviceManager;

  @override
  void stop() {
    super.stop();
    deviceManager.dispose();
  }
}

void main() {
  late DlnaService service;
  late _Device device;
  late DebugPrintCallback originalPrint;
  late List<String> logs;

  setUp(() async {
    logs = [];
    originalPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    device = _Device();
    final manager = _Manager();
    manager.deviceManager.deviceList[device.info.URLBase] = device;
    service = DlnaService(manager: manager);
    await service.startDiscovery();
  });

  tearDown(() async {
    service.dispose();
    await Future<void>.value();
    debugPrint = originalPrint;
  });

  test(
    '716 rejection logs action, TV endpoint, MIME and redacted resource',
    () async {
      device.failures.add('SetAVTransportURI');
      await expectLater(
        service.castTo(
          device.info.URLBase,
          'https://server/play?access_token=private-token&quality=original',
          title: '歌曲',
        ),
        throwsException,
      );
      final log = logs.join('\n');
      expect(log, contains('[DLNA] cast device=http://192.168.2.111:25826'));
      expect(log, contains('mime=http-get:*:audio/mp3:*'));
      expect(
        log,
        contains('url=https://server/play?access_token=***&quality=original'),
      );
      expect(log, contains('SetAVTransportURI failed attempt=4'));
      expect(log, contains('status 500 <errorCode>716</errorCode>'));
      expect(log, contains('Resource not found'));
      expect(log, isNot(contains('private-token')));
      expect(device.commands, everyElement('SetAVTransportURI'));
    },
  );

  test(
    'DIDL is a SOAP string and preserves URL and title entities after one decode',
    () async {
      const url =
          'https://server/play?access_token=private-token&quality=original';
      const title = '中文 & <曲名> "引号"';
      await service.castTo(device.info.URLBase, url, title: title);
      final envelope = DeviceInfoParser(device.requests.single).doc;
      final didl = envelope.tagVal('CurrentURIMetaData');
      expect(device.requests.single, isNot(contains('<DIDL-Lite')));
      final metadata = DeviceInfoParser(didl).doc;
      expect(metadata.tagVal('res'), url);
      expect(didl, contains('protocolInfo="http-get:*:audio/mp3:*"'));
      expect(metadata.tagVal('dc:title'), title);
      expect(envelope.tagVal('CurrentURI'), url);
      expect(device.commands, ['SetAVTransportURI', 'Play']);
    },
  );

  test('control and asynchronous disconnect failures are captured', () async {
    await service.castTo(device.info.URLBase, 'http://server/song.mp3');
    device.failures.addAll(['Pause', 'Stop']);
    await expectLater(service.pause(), throwsException);
    service.disconnect();
    await Future<void>.delayed(Duration.zero);
    final log = logs.join('\n');
    expect(log, contains('Play succeeded'));
    expect(log, contains('Pause failed:'));
    expect(log, contains('Stop failed:'));
    expect(log, isNot(contains('private-token')));
  });

  testWidgets('transport transitions are logged once per state change', (
    tester,
  ) async {
    device.responses['GetTransportInfo'] =
        '<root><CurrentTransportState>TRANSITIONING</CurrentTransportState>'
        '<CurrentTransportStatus>OK</CurrentTransportStatus></root>';
    await service.castTo(device.info.URLBase, 'http://server/song.mp3');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(
      logs.where((line) => line.contains('state=TRANSITIONING')),
      hasLength(1),
    );
    device.responses['GetTransportInfo'] =
        '<root><CurrentTransportState>PLAYING</CurrentTransportState>'
        '<CurrentTransportStatus>OK</CurrentTransportStatus></root>';
    await tester.pump(const Duration(seconds: 2));
    expect(logs.where((line) => line.contains('state=PLAYING')), hasLength(1));
    service.disconnect();
    debugPrint = tester.binding.debugPrintOverride;
  });
}
