import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';

// ============================================================================
// JS Plugin API Provider
// ============================================================================

/// JSPluginApi Provider
final jsPluginApiProvider = Provider<JSPluginApi>((ref) {
  final dio = ref.watch(dioProvider);
  return JSPluginApi(dio: dio);
});

// ============================================================================
// JS Plugin Data Providers
// ============================================================================

/// 获取 JS 插件列表
final jsPluginsProvider = FutureProvider<List<JSPlugin>>((ref) async {
  final api = ref.watch(jsPluginApiProvider);
  return api.getPlugins();
});

// ============================================================================
// Plugin Registry Providers
// ============================================================================

/// 获取插件订阅源列表
final pluginRegistriesProvider =
    FutureProvider<List<PluginRegistryConfig>>((ref) async {
  final api = ref.watch(settingsApiProvider);
  return api.getPluginRegistries();
});

// ============================================================================
// Plugin Keep-Alive Providers
// ============================================================================

/// 获取插件常驻白名单
final pluginKeepAliveProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(settingsApiProvider);
  return api.getPluginKeepAlive();
});

// ============================================================================
// Plugin Auto-Update Providers
// ============================================================================

/// 获取插件自动更新开关状态
final pluginAutoUpdateProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(settingsApiProvider);
  return api.getPluginAutoUpdate();
});
