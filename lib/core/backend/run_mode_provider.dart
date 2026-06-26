import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RunMode {
  remote,
  local,
}

const _kRunModeKey = 'songloft_run_mode';
const _kLocalMusicDirKey = 'songloft_local_music_dir';

/// 持久化用户选择的运行模式
class RunModeNotifier extends Notifier<RunMode> {
  @override
  RunMode build() {
    _load();
    return RunMode.remote;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kRunModeKey);
    if (value == 'local') {
      state = RunMode.local;
    }
  }

  Future<void> set(RunMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRunModeKey, mode.name);
  }
}

final runModeProvider = NotifierProvider<RunModeNotifier, RunMode>(
  RunModeNotifier.new,
);

/// 持久化用户选择的本地音乐目录
class LocalMusicDirNotifier extends Notifier<String?> {
  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kLocalMusicDirKey);
  }

  Future<void> set(String path) async {
    state = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocalMusicDirKey, path);
  }
}

final localMusicDirProvider = NotifierProvider<LocalMusicDirNotifier, String?>(
  LocalMusicDirNotifier.new,
);
