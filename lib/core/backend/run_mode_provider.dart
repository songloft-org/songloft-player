import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';

/// 当前构建是否允许本地模式：仅在非 Web 且编译期注入了 HAS_BACKEND 的 bundle
/// 构建下成立。与 servers_page 的 showLocalMode 判定保持一致。
const bool _localModeSupported = !kIsWeb && AppConfig.hasEmbeddedBackend;

enum RunMode {
  remote,
  local,
}

const _kRunModeKey = 'songloft_run_mode';
const _kLocalMusicDirKey = 'songloft_local_music_dir';

/// 持久化用户选择的运行模式
class RunModeNotifier extends Notifier<RunMode> {
  Completer<void> _loadCompleter = Completer<void>();

  @override
  RunMode build() {
    _loadCompleter = Completer<void>();
    _load();
    return RunMode.remote;
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      // 当前构建不支持本地模式（非 bundle 版）时，忽略历史持久化的 local，
      // 强制回退到 remote。否则换用非 bundle 版后，之前 bundle 版写入的
      // songloft_run_mode=local 会被恢复，UI 误显示「本地模式」
      // (songloft-org/songloft-player 非 bundle 版误显示本地模式修复)。
      if (!_localModeSupported) return;
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_kRunModeKey);
      if (value == 'local') {
        state = RunMode.local;
      }
    } finally {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
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
  Completer<void> _loadCompleter = Completer<void>();

  @override
  String? build() {
    _loadCompleter = Completer<void>();
    _load();
    return null;
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_kLocalMusicDirKey);
    } finally {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    }
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
