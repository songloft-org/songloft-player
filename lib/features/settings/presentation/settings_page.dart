import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/base_url_provider.dart';
import '../../../core/network/servers_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';
import 'widgets/cache_manager.dart';
import '../../../features/jsplugin/data/jsplugin_api.dart';
import '../../../features/jsplugin/presentation/providers/jsplugin_provider.dart';
import '../../../features/jsplugin/presentation/widgets/jsplugin_manager.dart';
import '../../../features/jsplugin/presentation/widgets/plugin_icon.dart';
import '../../../core/backend/run_mode_provider.dart';
import '../data/settings_api.dart';
import '../data/upgrade_api.dart';
import 'widgets/metadata_refresh_manager.dart';
import 'widgets/scan_manager.dart';
import 'widgets/section_card.dart';
import 'widgets/settings_master_detail.dart';
import 'widgets/theme_selector.dart';
import 'widgets/frontend_upgrade_dialog.dart';
import 'widgets/upgrade_dialog.dart';
import 'providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selectedCategory = 0;
  int? _mobileDetailIndex;

  static const _categories = [
    SettingsCategory(
      icon: Icons.palette_outlined,
      title: '外观设置',
      subtitle: '主题、菜单和显示',
    ),
    SettingsCategory(
      icon: Icons.play_circle_outlined,
      title: '播放设置',
      subtitle: '音质',
    ),
    SettingsCategory(
      icon: Icons.library_music_outlined,
      title: '音乐库管理',
      subtitle: '扫描、导入和转换',
    ),
    SettingsCategory(
      icon: Icons.extension_outlined,
      title: '扩展',
      subtitle: '插件管理',
    ),
    SettingsCategory(
      icon: Icons.storage_outlined,
      title: '缓存管理',
      subtitle: '服务端和本地缓存',
    ),
    SettingsCategory(
      icon: Icons.language_outlined,
      title: '网络设置',
      subtitle: '代理配置',
    ),
    SettingsCategory(
      icon: Icons.backup_outlined,
      title: '数据管理',
      subtitle: '歌单导出与导入',
    ),
    SettingsCategory(
      icon: Icons.system_update_outlined,
      title: '关于与更新',
      subtitle: '版本和日志',
    ),
    SettingsCategory(
      icon: Icons.account_circle_outlined,
      title: '账户',
      subtitle: '服务器和登录',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = !context.isWideScreen || context.isTv;

    if (isMobile && _mobileDetailIndex != null) {
      final category = _categories[_mobileDetailIndex!];
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _mobileDetailIndex = null);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => setState(() => _mobileDetailIndex = null),
            ),
            title: Text(category.title),
          ),
          body: _buildCategoryContent(_mobileDetailIndex!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SettingsMasterDetail(
        categories: _categories,
        selectedIndex: _selectedCategory,
        onCategorySelected: (i) {
          setState(() {
            _selectedCategory = i;
            if (isMobile) {
              _mobileDetailIndex = i;
            }
          });
        },
        contentBuilder: (_, index) => _buildCategoryContent(index),
        header: _buildServerInfoCard(),
      ),
    );
  }

  Widget _buildServerInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUrl = ref.watch(baseUrlProvider);
    final serverVersionAsync = ref.watch(serverVersionProvider);
    final versionText = serverVersionAsync.value;
    final versionLabel =
        versionText == null
            ? null
            : versionText == 'dev'
            ? '开发版'
            : 'v$versionText';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(
              Icons.dns_outlined,
              size: 22,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConfig.isEmbedded
                      ? 'Songloft'
                      : ref.watch(runModeProvider) == RunMode.local
                      ? '本地模式'
                      : currentUrl,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (versionLabel != null)
                  Text(
                    versionLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!AppConfig.isEmbedded)
            TextButton(
              onPressed: () => context.push(AppRoutes.servers),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('管理'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(int index) {
    final items = switch (index) {
      0 => _buildAppearanceItems(),
      1 => _buildPlaybackItems(),
      2 => _buildLibraryItems(),
      3 => _buildExtensionsItems(),
      4 => _buildCacheItems(),
      5 => _buildNetworkItems(),
      6 => _buildDataItems(),
      7 => _buildAboutItems(),
      8 => _buildAccountItems(),
      _ => <Widget>[],
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: _interleave(items, const SizedBox(height: AppSpacing.lg)),
    );
  }

  /// Insert a separator widget between each item in the list.
  List<Widget> _interleave(List<Widget> items, Widget separator) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(separator);
      }
    }
    return result;
  }

  // ── 外观设置 ──

  static const int _maxTabs = 12;
  static const int _fixedTabs = 2;

  List<Widget> _buildAppearanceItems() {
    final tabConfigAsync = ref.watch(tabConfigProvider);
    final pluginsAsync = ref.watch(jsPluginsProvider);
    final config = tabConfigAsync.value ?? TabConfig.defaultConfig();
    final plugins = pluginsAsync.value ?? [];
    final activePlugins =
        plugins
            .where(
              (p) =>
                  p.isActive && p.entryPath != null && p.entryPath!.isNotEmpty,
            )
            .toList();
    final usedCount = _fixedTabs + config.optionalCount;
    final atLimit = usedCount >= _maxTabs;

    return [
      const SectionCard(
        title: '主题',
        icon: Icons.palette_outlined,
        children: [
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text('主题模式'),
            subtitle: Text('选择应用的主题外观'),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: ThemeSelector(),
          ),
        ],
      ),
      SectionCard(
        title: '菜单设置',
        icon: Icons.tab_outlined,
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.library_music_outlined),
            title: const Text('歌曲库'),
            value: config.showLibrary,
            onChanged:
                atLimit && !config.showLibrary
                    ? null
                    : (value) => _updateTabConfig(
                      config.copyWith(showLibrary: value),
                      atLimit && value,
                    ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.queue_music_outlined),
            title: const Text('歌单'),
            value: config.showPlaylists,
            onChanged:
                atLimit && !config.showPlaylists
                    ? null
                    : (value) => _updateTabConfig(
                      config.copyWith(showPlaylists: value),
                      atLimit && value,
                    ),
          ),
          if (activePlugins.isNotEmpty) ...[
            const Divider(height: 1),
            ..._buildPluginTabTiles(config, activePlugins, atLimit),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Center(
              child: Text(
                '已启用 $usedCount 个标签（首页和设置固定显示）'
                '${usedCount > 5 ? '\n移动端超出 5 个时将折叠到「更多」菜单' : ''}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPluginTabTiles(
    TabConfig config,
    List<JSPlugin> activePlugins,
    bool atLimit,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < activePlugins.length; i++) {
      final plugin = activePlugins[i];
      final isEnabled = config.pluginTabs.any(
        (pt) => pt.entryPath == plugin.entryPath,
      );

      if (i > 0) widgets.add(const Divider(height: 1));
      widgets.add(
        SwitchListTile(
          secondary: PluginNavIcon(
            iconUrl: plugin.iconUrl,
            size: 24,
            fallbackIcon: const Icon(Icons.extension_outlined),
          ),
          title: Text(plugin.displayName),
          subtitle: plugin.version != null ? Text('v${plugin.version}') : null,
          value: isEnabled,
          onChanged:
              atLimit && !isEnabled
                  ? null
                  : (value) {
                    final newPluginTabs = List<PluginTabEntry>.from(
                      config.pluginTabs,
                    );
                    if (value) {
                      newPluginTabs.add(
                        PluginTabEntry(
                          pluginId: plugin.id,
                          entryPath: plugin.entryPath!,
                          name: plugin.displayName,
                        ),
                      );
                    } else {
                      newPluginTabs.removeWhere(
                        (pt) => pt.entryPath == plugin.entryPath,
                      );
                    }
                    _updateTabConfig(
                      config.copyWith(pluginTabs: newPluginTabs),
                      atLimit && value,
                    );
                  },
        ),
      );
    }
    return widgets;
  }

  Future<void> _updateTabConfig(TabConfig config, bool wouldExceedLimit) async {
    if (wouldExceedLimit) {
      ResponsiveSnackBar.showError(context, message: '最多显示 $_maxTabs 个标签');
      return;
    }
    try {
      await ref.read(tabConfigProvider.notifier).updateConfig(config);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: '保存失败: $e');
    }
  }

  // ── 播放设置 ──

  List<Widget> _buildPlaybackItems() {
    final quality = ref.watch(audioQualityProvider);
    const labels = {
      'original': '原始音质',
      '128': '低 (128kbps)',
      '192': '中 (192kbps)',
      '320': '高 (320kbps)',
    };
    return [
      SectionCard(
        title: '播放设置',
        icon: Icons.play_circle_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text('音质'),
            subtitle: Text(labels[quality] ?? '原始音质'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<String>(
                context: context,
                builder:
                    (ctx) => SimpleDialog(
                      title: const Text('选择音质'),
                      children: [
                        RadioGroup<String>(
                          groupValue: quality,
                          onChanged: (v) => Navigator.pop(ctx, v),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                labels.entries
                                    .map(
                                      (e) => RadioListTile<String>(
                                        title: Text(e.value),
                                        subtitle:
                                            e.key == 'original'
                                                ? const Text('不转码，使用文件原始码率')
                                                : const Text('转码为 MP3，适合弱网环境'),
                                        value: e.key,
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
              );
              if (picked == null || picked == quality) return;
              try {
                await ref
                    .read(audioQualityProvider.notifier)
                    .setQuality(picked);
                if (!mounted) return;
                ResponsiveSnackBar.show(
                  context,
                  message: '音质已切换为${labels[picked]}',
                );
              } catch (e) {
                if (!mounted) return;
                ResponsiveSnackBar.showError(context, message: '切换失败: $e');
              }
            },
          ),
        ],
      ),
    ];
  }

  // ── 音乐库管理 ──

  List<Widget> _buildLibraryItems() {
    return [
      SectionCard(
        title: '音乐库管理',
        icon: Icons.library_music_outlined,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: ScanManager()),
          const Divider(height: 1),
          const MetadataRefreshManager(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('重复歌曲检测'),
            subtitle: const Text('通过音频指纹识别内容相同的重复文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.duplicateCheck),
          ),
        ],
      ),
    ];
  }

  // ── 扩展 ──

  List<Widget> _buildExtensionsItems() {
    return [
      SectionCard(
        title: '扩展',
        icon: Icons.extension_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('插件商店'),
            subtitle: const Text('浏览和安装插件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.pluginRegistry),
          ),
          const Divider(height: 1),
          const JSPluginManager(),
        ],
      ),
    ];
  }

  // ── 缓存管理 ──

  List<Widget> _buildCacheItems() {
    return [
      const SectionCard(
        title: '缓存管理',
        icon: Icons.storage_outlined,
        children: [CacheManager()],
      ),
    ];
  }

  // ── 网络设置 ──

  List<Widget> _buildNetworkItems() {
    return [
      SectionCard(
        title: '网络设置',
        icon: Icons.language_outlined,
        children: [
          _buildHttpProxyTile(),
          const Divider(height: 1),
          _buildHlsProxyTile(),
        ],
      ),
    ];
  }

  // ── 数据管理 ──

  List<Widget> _buildDataItems() {
    return [
      SectionCard(
        title: '数据管理',
        icon: Icons.backup_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出歌单'),
            subtitle: const Text('将所有歌单数据备份为 JSON 文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportPlaylists,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导入歌单'),
            subtitle: const Text('从 JSON 备份文件还原歌单数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importPlaylists,
          ),
        ],
      ),
    ];
  }

  // ── 关于与更新 ──

  List<Widget> _buildAboutItems() {
    return [
      SectionCard(
        title: '关于与更新',
        icon: Icons.system_update_outlined,
        children: [
          _buildServerVersionTile(),
          if (!AppConfig.isEmbedded) ...[
            const Divider(height: 1),
            _buildFrontendUpdateTile(),
          ],
          const Divider(height: 1),
          _buildLogLevelTile(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('版本信息和许可证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    ];
  }

  // ── 账户 ──

  List<Widget> _buildAccountItems() {
    return [
      SectionCard(
        title: '账户',
        icon: Icons.account_circle_outlined,
        children: [
          if (!AppConfig.isEmbedded) ...[
            ListTile(
              leading: Icon(
                ref.watch(runModeProvider) == RunMode.local
                    ? Icons.phone_android
                    : Icons.link,
              ),
              title: Text(
                ref.watch(runModeProvider) == RunMode.local ? '本地模式' : '服务器',
              ),
              subtitle:
                  ref.watch(runModeProvider) == RunMode.local
                      ? Text(
                        ref.watch(localMusicDirProvider) ?? '未选择音乐目录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                      : _buildApiUrlSubtitle(),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.servers),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '退出登录',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    ];
  }

  // ── 业务逻辑方法（保持不变） ──

  Future<void> _exportPlaylists() async {
    final token = SecureStorageService.cachedAccessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: '未登录，无法导出');
      return;
    }
    final url =
        '${AppConfig.baseUrl}${AppConfig.apiPrefix}/playlists/export?access_token=$token';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: '导出失败: $e');
    }
  }

  Future<void> _importPlaylists() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      late final MultipartFile multipartFile;

      if (kIsWeb) {
        if (file.bytes == null) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(context, message: '无法读取文件内容');
          return;
        }
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else {
        if (file.path == null) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(context, message: '无法获取文件路径');
          return;
        }
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        );
      }

      final formData = FormData.fromMap({'file': multipartFile});
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '${AppConfig.apiPrefix}/playlists/import',
        data: formData,
      );

      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      final created = data['playlists_created'] ?? 0;
      final merged = data['playlists_merged'] ?? 0;
      final songsCreated = data['songs_created'] ?? 0;
      final songsMatched = data['songs_matched'] ?? 0;

      ResponsiveSnackBar.show(
        context,
        message:
            '导入完成: 新建歌单 $created, 合并歌单 $merged, '
            '新建歌曲 $songsCreated, 匹配歌曲 $songsMatched',
      );

      ref.invalidate(playlistListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail =
          (e.response?.data as Map<String, dynamic>?)?['error'] as String?;
      ResponsiveSnackBar.showError(
        context,
        message: '导入失败: ${detail ?? e.message}',
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: '导入失败: $e');
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定要退出当前账户吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('确认退出'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  Widget _buildServerVersionTile() {
    final upgradeCheck = ref.watch(upgradeCheckProvider);

    return upgradeCheck.when(
      data: (check) {
        final currentVersion = _formatServerUpgradeVersion(check);
        final hasUpdate = check.hasUpdate && check.availableUpdates.isNotEmpty;
        final subtitle =
            hasUpdate
                ? '发现新版本: ${check.availableUpdates.first.version}'
                : '当前版本: $currentVersion (已是最新)';

        return ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('检查服务端更新'),
          subtitle: Text(
            subtitle,
            style:
                hasUpdate
                    ? TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                    : null,
          ),
          trailing:
              hasUpdate
                  ? Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  )
                  : const Icon(Icons.chevron_right),
          onTap: () => UpgradeDialog.show(context),
        );
      },
      loading:
          () => const ListTile(
            leading: Icon(Icons.dns),
            title: Text('检查服务端更新'),
            subtitle: Text('正在检查更新...'),
            trailing: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (_, _) => ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('检查服务端更新'),
            subtitle: const Text('检查更新失败'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpgradeDialog.show(context),
          ),
    );
  }

  String _formatServerUpgradeVersion(UpgradeCheck check) {
    final versionText = check.currentVersion ?? '未知';
    final details = <String>[];
    if (check.currentChannel == 'dev') {
      details.add('开发版');
    } else if (check.currentChannel == 'stable') {
      details.add('正式版');
    }
    if (check.currentBuildType != null && check.currentBuildType!.isNotEmpty) {
      details.add(check.currentBuildType!);
    }
    return details.isEmpty
        ? versionText
        : '$versionText (${details.join(', ')})';
  }

  Widget _buildFrontendUpdateTile() {
    final frontendCheck = ref.watch(frontendVersionCheckProvider);
    final versionDisplay = AppConfig.frontendVersionDisplay;

    return frontendCheck.when(
      data: (check) {
        final subtitle =
            check.hasUpdate
                ? '发现新版本: ${check.latestVersionDisplay}'
                : '当前版本: $versionDisplay (已是最新)';

        return ListTile(
          leading: const Icon(Icons.phone_android),
          title: const Text('检查客户端更新'),
          subtitle: Text(
            subtitle,
            style:
                check.hasUpdate
                    ? TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                    : null,
          ),
          trailing:
              check.hasUpdate
                  ? Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  )
                  : const Icon(Icons.chevron_right),
          onTap: () => FrontendUpgradeDialog.show(context),
        );
      },
      loading:
          () => ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('检查客户端更新'),
            subtitle: Text('当前版本: $versionDisplay'),
            trailing: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (_, _) => ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('检查客户端更新'),
            subtitle: Text('当前版本: $versionDisplay'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => FrontendUpgradeDialog.show(context),
          ),
    );
  }

  Widget _buildHlsProxyTile() {
    final enabledAsync = ref.watch(hlsProxyEnabledProvider);
    final enabled = enabledAsync.value ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.cell_tower_outlined),
      title: const Text('HLS 电台后端代理'),
      subtitle: const Text(
        '开启后服务端拉取电台 m3u8 并代理切片,可绕过 Referer 防盗链 / CORS。'
        '所有切片走本机带宽,注意流量成本',
      ),
      value: enabled,
      onChanged:
          enabledAsync.isLoading
              ? null
              : (value) async {
                try {
                  await ref
                      .read(hlsProxyEnabledProvider.notifier)
                      .setValue(value);
                  if (!mounted) return;
                  ResponsiveSnackBar.show(
                    context,
                    message: value ? '已开启 HLS 代理' : '已关闭 HLS 代理',
                  );
                } catch (e) {
                  if (!mounted) return;
                  ResponsiveSnackBar.showError(context, message: '保存失败: $e');
                }
              },
    );
  }

  Widget _buildHttpProxyTile() {
    final proxyAsync = ref.watch(httpProxyProvider);
    final proxy = proxyAsync.value ?? '';

    return ListTile(
      leading: const Icon(Icons.vpn_lock_outlined),
      title: const Text('HTTP 代理'),
      subtitle: Text(proxy.isEmpty ? '未配置（直连）' : proxy),
      trailing: const Icon(Icons.chevron_right),
      enabled: !proxyAsync.isLoading,
      onTap: () async {
        final controller = TextEditingController(text: proxy);
        final result = await showDialog<String>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('HTTP 代理'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设置全局 HTTP 代理，所有后端外发请求（插件下载、升级检查等）将通过此代理转发。留空则直连。',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: '代理地址',
                        hintText: 'http://192.168.1.1:7890',
                        helperText: '支持 HTTP/HTTPS/SOCKS5 代理',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  if (proxy.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('清除'),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: const Text('保存'),
                  ),
                ],
              ),
        );
        if (result == null || result == proxy) return;
        try {
          await ref.read(httpProxyProvider.notifier).setValue(result);
          if (!mounted) return;
          ResponsiveSnackBar.show(
            context,
            message: result.isEmpty ? '已清除 HTTP 代理' : 'HTTP 代理已设置为 $result',
          );
        } catch (e) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(context, message: '保存失败: $e');
        }
      },
    );
  }

  Widget _buildLogLevelTile() {
    final levelAsync = ref.watch(logLevelProvider);
    final level = levelAsync.value ?? 'info';
    const labels = {
      'debug': 'Debug（详细，调试用）',
      'info': 'Info（默认）',
      'warn': 'Warn',
      'error': 'Error（仅错误）',
    };
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: const Text('日志等级'),
      subtitle: Text(labels[level] ?? level),
      trailing: const Icon(Icons.chevron_right),
      enabled: !levelAsync.isLoading,
      onTap: () async {
        final picked = await showDialog<String>(
          context: context,
          builder:
              (ctx) => SimpleDialog(
                title: const Text('选择日志等级'),
                children: [
                  RadioGroup<String>(
                    groupValue: level,
                    onChanged: (v) => Navigator.pop(ctx, v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          labels.entries
                              .map(
                                (e) => RadioListTile<String>(
                                  title: Text(e.value),
                                  value: e.key,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
        );
        if (picked == null || picked == level) return;
        try {
          await ref.read(logLevelProvider.notifier).setValue(picked);
          if (!mounted) return;
          ResponsiveSnackBar.show(
            context,
            message: '日志等级已切换为 ${labels[picked] ?? picked}',
          );
        } catch (e) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(context, message: '切换失败: $e');
        }
      },
    );
  }

  Widget _buildApiUrlSubtitle() {
    final serversAsync = ref.watch(serversProvider);
    final currentUrl = ref.watch(baseUrlProvider);
    return serversAsync.when(
      data: (servers) {
        if (servers.isEmpty) return const Text('未配置 · 点击添加');
        final current = servers.firstWhere(
          (s) => s.url == currentUrl,
          orElse: () => servers.first,
        );
        final label = current.name.isNotEmpty ? current.name : current.url;
        return Text('${servers.length} 个地址 · 当前: $label');
      },
      loading: () => const Text('加载中...'),
      error: (_, _) => const Text('加载失败'),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAboutDialog() async {
    String version = '1.0.0';
    String? gitCommit;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio
          .get('${AppConfig.apiPrefix}/version')
          .timeout(const Duration(seconds: 3));
      final data = response.data as Map<String, dynamic>;
      final ver = data['version'] as String?;
      if (ver != null && ver.isNotEmpty) {
        version = ver;
      }
      final commit = data['git_commit'] as String?;
      if (commit != null && commit != 'unknown' && commit.isNotEmpty) {
        gitCommit = commit;
      }
    } catch (_) {}

    if (!mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Songloft',
      applicationVersion: version,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: 48,
          height: 48,
          semanticLabel: 'Songloft',
        ),
      ),
      applicationLegalese: '© 2024-2026 Songloft. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text('Songloft 是一个开源的个人音乐服务器应用。'),
        const SizedBox(height: 8),
        const Text('支持本地音乐库管理、在线播放和插件扩展。'),
        if (gitCommit != null) ...[
          const SizedBox(height: 8),
          Text(
            'Git: $gitCommit',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          link: true,
          label: '打开 GitHub 页面',
          child: InkWell(
            onTap: () => _launchUrl('https://github.com/songloft-org/songloft'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'GitHub: songloft-org/songloft',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
