import 'dart:async';
import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart';
import '../domain/dlna_state.dart';

class DlnaService {
  final DLNAManager _manager = DLNAManager();
  DeviceManager? _deviceManager;
  DLNADevice? _activeDevice;
  StreamSubscription? _positionSub;

  Timer? _transportTimer;
  bool _hasStartedPlaying = false;
  bool _suppressCompletion = false; // 重新投歌期间抑制完成误判

  final _devicesController =
      StreamController<List<DlnaDeviceInfo>>.broadcast();
  final _positionController =
      StreamController<PositionParser>.broadcast();
  final _completionController = StreamController<void>.broadcast();

  Stream<List<DlnaDeviceInfo>> get devicesStream => _devicesController.stream;
  Stream<PositionParser> get positionStream => _positionController.stream;

  /// 设备端播放完成事件（当前曲在渲染设备上播完时触发）
  Stream<void> get completionStream => _completionController.stream;
  DLNADevice? get activeDevice => _activeDevice;

  Future<void> startDiscovery() async {
    _deviceManager = await _manager.start();
    _deviceManager!.devices.stream.listen((deviceMap) {
      final devices = deviceMap.values
          .map(
            (d) => DlnaDeviceInfo(
              id: d.info.URLBase,
              name: d.info.friendlyName,
              location: d.info.URLBase,
            ),
          )
          .toList();
      _devicesController.add(devices);
    });
  }

  void stopDiscovery() {
    _manager.stop();
    _deviceManager = null;
  }

  Future<void> castTo(
    String deviceId,
    String url, {
    String title = '',
    PlayType mime = AudioMime.mp3,
  }) async {
    final device = _deviceManager?.deviceList[deviceId];
    if (device == null) throw Exception('Device not found: $deviceId');

    _activeDevice = device;
    // 切歌期间设备会短暂进入 STOPPED/TRANSITIONING，抑制完成检测避免误推进
    _suppressCompletion = true;
    _hasStartedPlaying = false;
    try {
      // mime 由调用方按歌曲真实格式决定（视频→VideoMime，音频→对应 AudioMime），
      // 不再硬编码 mp3：写死 mp3 会让 DIDL 永远声明 audio/mp3，非 mp3（flac/wav）或视频投屏可能被渲染器拒绝。
      await _sendWithRetry(
        () => device.setUrl(url, title: title, type: mime),
      );
      await _sendWithRetry(() => device.play());
    } finally {
      _suppressCompletion = false;
    }

    _positionSub?.cancel();
    device.positionPoller.start();
    _positionSub = device.currPosition.stream.listen((pos) {
      _positionController.add(pos);
    });

    _startCompletionMonitor();
  }

  /// 设备在切歌/播放结束瞬间会主动关闭连接（HttpException: Connection closed
  /// before full header was received），此处带指数退避重试兜底。
  Future<void> _sendWithRetry(
    Future<String> Function() action, {
    int retries = 3,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        await action();
        return;
      } catch (_) {
        if (attempt >= retries) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 400 * (attempt + 1)),
        );
      }
    }
  }

  /// 轮询设备 transport 状态，检测当前曲播放完成。
  /// 播放中标记 _hasStartedPlaying，转为 STOPPED/NO_MEDIA 时判定为播完。
  void _startCompletionMonitor() {
    _transportTimer?.cancel();
    _transportTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final device = _activeDevice;
      if (device == null || _suppressCompletion) return;
      try {
        final xml = await device.getTransportInfo();
        final s = TransportInfoParser(xml).CurrentTransportState.toUpperCase();
        if (s == 'PLAYING' || s == 'TRANSITIONING') {
          _hasStartedPlaying = true;
        } else if (s == 'STOPPED' || s == 'NO_MEDIA_PRESENT') {
          if (_hasStartedPlaying && !_suppressCompletion) {
            _hasStartedPlaying = false;
            if (!_completionController.isClosed) {
              _completionController.add(null);
            }
          }
        }
      } catch (_) {
        // 忽略设备切歌/结束瞬间的连接错误，下一轮继续
      }
    });
  }

  void _stopCompletionMonitor() {
    _transportTimer?.cancel();
    _transportTimer = null;
    _hasStartedPlaying = false;
  }

  Future<void> play() async => _activeDevice?.play();
  Future<void> pause() async => _activeDevice?.pause();

  Future<void> stop() async {
    _stopCompletionMonitor();
    _activeDevice?.positionPoller.stop();
    _positionSub?.cancel();
    await _activeDevice?.stop();
  }

  Future<void> seek(Duration position) async {
    final h = position.inHours.toString().padLeft(2, '0');
    final m = (position.inMinutes % 60).toString().padLeft(2, '0');
    final s = (position.inSeconds % 60).toString().padLeft(2, '0');
    await _activeDevice?.seek('$h:$m:$s');
  }

  Future<void> setVolume(int volume) async =>
      _activeDevice?.volume(volume.clamp(0, 100));

  void disconnect() {
    _stopCompletionMonitor();
    _positionSub?.cancel();
    _activeDevice?.positionPoller.stop();
    try {
      _activeDevice?.stop();
    } catch (_) {}
    _activeDevice = null;
  }

  void dispose() {
    _stopCompletionMonitor();
    _positionSub?.cancel();
    _activeDevice?.dispose();
    stopDiscovery();
    _devicesController.close();
    _positionController.close();
    _completionController.close();
  }
}
