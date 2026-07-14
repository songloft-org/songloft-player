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
import '../../../core/network/insecure_tls_provider.dart';
import '../../../core/network/servers_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/platform_utils.dart';
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
import 'widgets/language_selector.dart';
import '../../../l10n/app_localizations.dart';
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

  List<SettingsCategory> _buildCategories(AppLocalizations l10n) => [
    SettingsCategory(
      icon: Icons.palette_outlined,
      title: l10n.settingsCategoryAppearanceTitle,
      subtitle: l10n.settingsCategoryAppearanceSubtitle,
    ),
    SettingsCategory(
      icon: Icons.play_circle_outlined,
      title: l10n.settingsCategoryPlaybackTitle,
      subtitle: l10n.settingsCategoryPlaybackSubtitle,
    ),
    SettingsCategory(
      icon: Icons.library_music_outlined,
      title: l10n.settingsCategoryLibraryTitle,
      subtitle: l10n.settingsCategoryLibrarySubtitle,
    ),
    SettingsCategory(
      icon: Icons.extension_outlined,
      title: l10n.settingsCategoryExtensionsTitle,
      subtitle: l10n.settingsCategoryExtensionsSubtitle,
    ),
    SettingsCategory(
      icon: Icons.storage_outlined,
      title: l10n.settingsCategoryCacheTitle,
      subtitle: l10n.settingsCategoryCacheSubtitle,
    ),
    SettingsCategory(
      icon: Icons.language_outlined,
      title: l10n.settingsCategoryNetworkTitle,
      subtitle: l10n.settingsCategoryNetworkSubtitle,
    ),
    SettingsCategory(
      icon: Icons.backup_outlined,
      title: l10n.settingsCategoryDataTitle,
      subtitle: l10n.settingsCategoryDataSubtitle,
    ),
    SettingsCategory(
      icon: Icons.system_update_outlined,
      title: l10n.settingsCategoryAboutTitle,
      subtitle: l10n.settingsCategoryAboutSubtitle,
    ),
    SettingsCategory(
      icon: Icons.account_circle_outlined,
      title: l10n.settingsCategoryAccountTitle,
      subtitle: l10n.settingsCategoryAccountSubtitle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _buildCategories(l10n);
    // 与 SettingsMasterDetail 共用同一布局判断，避免漂移导致车机超宽比下渲染
    // 移动端列表却不响应点击的「按钮失效」(songloft-org/songloft#268)。
    final isMobile = !context.useWideLayout;

    if (isMobile && _mobileDetailIndex != null) {
      final category = categories[_mobileDetailIndex!];
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
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: SettingsMasterDetail(
        categories: categories,
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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUrl = ref.watch(baseUrlProvider);
    final serverVersionAsync = ref.watch(serverVersionProvider);
    final versionText = serverVersionAsync.value;
    final versionLabel =
        versionText == null
            ? null
            : versionText == 'dev'
            ? l10n.settingsDevVersion
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
                      ? l10n.settingsLocalMode
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
              child: Text(l10n.settingsManage),
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
    final l10n = AppLocalizations.of(context);

    return [
      SectionCard(
        title: l10n.themeTitle,
        icon: Icons.palette_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.themeModeTitle),
            subtitle: Text(l10n.themeModeSubtitle),
          ),
          const Padding(
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
        title: l10n.language,
        icon: Icons.translate_outlined,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: LanguageSelector(),
          ),
        ],
      ),
      SectionCard(
        title: l10n.settingsMenuTitle,
        icon: Icons.tab_outlined,
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.library_music_outlined),
            title: Text(l10n.settingsMenuLibrary),
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
            title: Text(l10n.settingsMenuPlaylists),
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
                l10n.settingsTabsEnabledCount(usedCount) +
                    (usedCount > 5 ? '\n${l10n.settingsTabsCollapseHint}' : ''),
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
    final l10n = AppLocalizations.of(context);
    if (wouldExceedLimit) {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsMaxTabsLimit(_maxTabs),
      );
      return;
    }
    try {
      await ref.read(tabConfigProvider.notifier).updateConfig(config);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsSaveFailed(e.toString()),
      );
    }
  }

  // ── 播放设置 ──

  List<Widget> _buildPlaybackItems() {
    final l10n = AppLocalizations.of(context);
    final quality = ref.watch(audioQualityProvider);
    final labels = {
      'original': l10n.settingsQualityOriginal,
      '128': l10n.settingsQualityLow,
      '192': l10n.settingsQualityMedium,
      '320': l10n.settingsQualityHigh,
    };
    return [
      SectionCard(
        title: l10n.settingsCategoryPlaybackTitle,
        icon: Icons.play_circle_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text(l10n.settingsQualityTitle),
            subtitle: Text(labels[quality] ?? l10n.settingsQualityOriginal),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<String>(
                context: context,
                builder:
                    (ctx) => SimpleDialog(
                      title: Text(l10n.settingsQualityDialogTitle),
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
                                                ? Text(
                                                  l10n.settingsQualityOriginalDesc,
                                                )
                                                : Text(
                                                  l10n.settingsQualityTranscodeDesc,
                                                ),
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
                  message: l10n.settingsQualitySwitched(labels[picked] ?? ''),
                );
              } catch (e) {
                if (!mounted) return;
                ResponsiveSnackBar.showError(
                  context,
                  message: l10n.settingsSwitchFailed(e.toString()),
                );
              }
            },
          ),
          // 键盘快捷键（仅桌面）
          if (PlatformUtils.isDesktop) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: Text(l10n.settingsShortcutsEntryTitle),
              subtitle: Text(l10n.settingsShortcutsEntrySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.shortcuts),
            ),
          ],
        ],
      ),
    ];
  }

  // ── 音乐库管理 ──

  List<Widget> _buildLibraryItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryLibraryTitle,
        icon: Icons.library_music_outlined,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: ScanManager()),
          const Divider(height: 1),
          const MetadataRefreshManager(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(l10n.settingsLibraryDuplicateTitle),
            subtitle: Text(l10n.settingsLibraryDuplicateSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.duplicateCheck),
          ),
        ],
      ),
    ];
  }

  // ── 扩展 ──

  List<Widget> _buildExtensionsItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryExtensionsTitle,
        icon: Icons.extension_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: Text(l10n.settingsPluginStoreTitle),
            subtitle: Text(l10n.settingsPluginStoreSubtitle),
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
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryCacheTitle,
        icon: Icons.storage_outlined,
        children: const [CacheManager()],
      ),
    ];
  }

  // ── 网络设置 ──

  List<Widget> _buildNetworkItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryNetworkTitle,
        icon: Icons.language_outlined,
        children: [
          _buildHttpProxyTile(),
          const Divider(height: 1),
          _buildHlsProxyTile(),
          const Divider(height: 1),
          _buildInsecureTlsTile(),
        ],
      ),
    ];
  }

  // ── 数据管理 ──

  List<Widget> _buildDataItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryDataTitle,
        icon: Icons.backup_outlined,
        children: [
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.settingsExportPlaylistTitle),
            subtitle: Text(l10n.settingsExportPlaylistSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportPlaylists,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(l10n.settingsImportPlaylistTitle),
            subtitle: Text(l10n.settingsImportPlaylistSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importPlaylists,
          ),
        ],
      ),
    ];
  }

  // ── 关于与更新 ──

  List<Widget> _buildAboutItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryAboutTitle,
        icon: Icons.system_update_outlined,
        children: [
          _buildServerVersionTile(),
          if (!AppConfig.isEmbedded) ...[
            const Divider(height: 1),
            _buildFrontendUpdateTile(),
          ],
          const Divider(height: 1),
          _buildLogLevelTile(),
          if (kIsWeb) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.settingsDownloadAppTitle),
              subtitle: Text(l10n.settingsDownloadAppSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.clientDownload),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAboutTitle),
            subtitle: Text(l10n.settingsAboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    ];
  }

  // ── 账户 ──

  List<Widget> _buildAccountItems() {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        title: l10n.settingsCategoryAccountTitle,
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
                ref.watch(runModeProvider) == RunMode.local
                    ? l10n.settingsLocalMode
                    : l10n.settingsAccountServer,
              ),
              subtitle:
                  ref.watch(runModeProvider) == RunMode.local
                      ? Text(
                        ref.watch(localMusicDirProvider) ??
                            l10n.settingsNoMusicDir,
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
              l10n.settingsLogout,
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
    final l10n = AppLocalizations.of(context);
    final token = SecureStorageService.cachedAccessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsExportNotLoggedIn,
      );
      return;
    }
    final url =
        '${AppConfig.baseUrl}${AppConfig.apiPrefix}/playlists/export?access_token=$token';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsExportFailed(e.toString()),
      );
    }
  }

  Future<void> _importPlaylists() async {
    final l10n = AppLocalizations.of(context);
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
          ResponsiveSnackBar.showError(
            context,
            message: l10n.settingsImportReadFailed,
          );
          return;
        }
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else {
        if (file.path == null) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(
            context,
            message: l10n.settingsImportPathFailed,
          );
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
        message: l10n.settingsImportComplete(
          created,
          merged,
          songsCreated,
          songsMatched,
        ),
      );

      ref.invalidate(playlistListProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail =
          (e.response?.data as Map<String, dynamic>?)?['error'] as String?;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsImportFailed(detail ?? e.message ?? ''),
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsImportFailed(e.toString()),
      );
    }
  }

  Future<void> _showLogoutDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsLogoutConfirmTitle),
            content: Text(l10n.settingsLogoutConfirmContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.settingsLogoutButton),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  Widget _buildServerVersionTile() {
    final l10n = AppLocalizations.of(context);
    final upgradeCheck = ref.watch(upgradeCheckProvider);

    return upgradeCheck.when(
      data: (check) {
        final currentVersion = _formatServerUpgradeVersion(check);
        final hasUpdate = check.hasUpdate && check.availableUpdates.isNotEmpty;
        final subtitle =
            hasUpdate
                ? l10n.settingsUpdateAvailable(
                  check.availableUpdates.first.version,
                )
                : l10n.settingsCurrentVersionLatest(currentVersion);

        return ListTile(
          leading: const Icon(Icons.dns),
          title: Text(l10n.settingsCheckServerUpdate),
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
          () => ListTile(
            leading: const Icon(Icons.dns),
            title: Text(l10n.settingsCheckServerUpdate),
            subtitle: Text(l10n.settingsCheckingUpdate),
            trailing: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (_, _) => ListTile(
            leading: const Icon(Icons.dns),
            title: Text(l10n.settingsCheckServerUpdate),
            subtitle: Text(l10n.settingsCheckUpdateFailed),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpgradeDialog.show(context),
          ),
    );
  }

  String _formatServerUpgradeVersion(UpgradeCheck check) {
    final l10n = AppLocalizations.of(context);
    final versionText = check.currentVersion ?? l10n.commonUnknown;
    final details = <String>[];
    if (check.currentChannel == 'dev') {
      details.add(l10n.settingsDevVersion);
    } else if (check.currentChannel == 'stable') {
      details.add(l10n.settingsStableVersion);
    }
    if (check.currentBuildType != null && check.currentBuildType!.isNotEmpty) {
      details.add(check.currentBuildType!);
    }
    return details.isEmpty
        ? versionText
        : '$versionText (${details.join(', ')})';
  }

  Widget _buildFrontendUpdateTile() {
    final l10n = AppLocalizations.of(context);
    final frontendCheck = ref.watch(frontendVersionCheckProvider);
    final versionDisplay = AppConfig.frontendVersionDisplay;

    return frontendCheck.when(
      data: (check) {
        final subtitle =
            check.hasUpdate
                ? l10n.settingsUpdateAvailable(check.latestVersionDisplay)
                : l10n.settingsCurrentVersionLatest(versionDisplay);

        return ListTile(
          leading: const Icon(Icons.phone_android),
          title: Text(l10n.settingsCheckClientUpdate),
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
            title: Text(l10n.settingsCheckClientUpdate),
            subtitle: Text(l10n.settingsCurrentVersion(versionDisplay)),
            trailing: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (_, _) => ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(l10n.settingsCheckClientUpdate),
            subtitle: Text(l10n.settingsCurrentVersion(versionDisplay)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => FrontendUpgradeDialog.show(context),
          ),
    );
  }

  Widget _buildHlsProxyTile() {
    final l10n = AppLocalizations.of(context);
    final enabledAsync = ref.watch(hlsProxyEnabledProvider);
    final enabled = enabledAsync.value ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.cell_tower_outlined),
      title: Text(l10n.settingsHlsProxyTitle),
      subtitle: Text(l10n.settingsHlsProxySubtitle),
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
                    message:
                        value
                            ? l10n.settingsHlsProxyEnabled
                            : l10n.settingsHlsProxyDisabled,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ResponsiveSnackBar.showError(
                    context,
                    message: l10n.settingsSaveFailed(e.toString()),
                  );
                }
              },
    );
  }

  Widget _buildInsecureTlsTile() {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(insecureTlsProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.gpp_maybe_outlined),
      title: Text(l10n.settingsInsecureTlsTitle),
      subtitle: Text(l10n.settingsInsecureTlsSubtitle),
      value: enabled,
      onChanged: (value) async {
        // 开启前弹安全警告确认；关闭无需确认
        if (value) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: Text(l10n.settingsInsecureTlsWarnTitle),
                  content: Text(l10n.settingsInsecureTlsWarnContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(l10n.commonConfirm),
                    ),
                  ],
                ),
          );
          if (confirmed != true) return;
        }
        await ref.read(insecureTlsProvider.notifier).setValue(value);
        if (!mounted) return;
        ResponsiveSnackBar.show(
          context,
          message:
              value
                  ? l10n.settingsInsecureTlsEnabled
                  : l10n.settingsInsecureTlsDisabled,
        );
      },
    );
  }

  Widget _buildHttpProxyTile() {
    final l10n = AppLocalizations.of(context);
    final proxyAsync = ref.watch(httpProxyProvider);
    final proxy = proxyAsync.value ?? '';

    return ListTile(
      leading: const Icon(Icons.vpn_lock_outlined),
      title: Text(l10n.settingsHttpProxyTitle),
      subtitle: Text(proxy.isEmpty ? l10n.settingsHttpProxyNotConfigured : proxy),
      trailing: const Icon(Icons.chevron_right),
      enabled: !proxyAsync.isLoading,
      onTap: () async {
        final controller = TextEditingController(text: proxy);
        final result = await showDialog<String>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(l10n.settingsHttpProxyTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsHttpProxyDialogDesc),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: l10n.settingsHttpProxyAddressLabel,
                        hintText: 'http://192.168.1.1:7890',
                        helperText: l10n.settingsHttpProxyHelper,
                        helperMaxLines: 2,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.commonCancel),
                  ),
                  if (proxy.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: Text(l10n.settingsClear),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: Text(l10n.settingsSave),
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
            message:
                result.isEmpty
                    ? l10n.settingsHttpProxyCleared
                    : l10n.settingsHttpProxySet(result),
          );
        } catch (e) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(
            context,
            message: l10n.settingsSaveFailed(e.toString()),
          );
        }
      },
    );
  }

  Widget _buildLogLevelTile() {
    final l10n = AppLocalizations.of(context);
    final levelAsync = ref.watch(logLevelProvider);
    final level = levelAsync.value ?? 'info';
    final labels = {
      'debug': l10n.settingsLogLevelDebug,
      'info': l10n.settingsLogLevelInfo,
      'warn': l10n.settingsLogLevelWarn,
      'error': l10n.settingsLogLevelError,
    };
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: Text(l10n.settingsLogLevelTitle),
      subtitle: Text(labels[level] ?? level),
      trailing: const Icon(Icons.chevron_right),
      enabled: !levelAsync.isLoading,
      onTap: () async {
        final picked = await showDialog<String>(
          context: context,
          builder:
              (ctx) => SimpleDialog(
                title: Text(l10n.settingsLogLevelDialogTitle),
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
            message: l10n.settingsLogLevelSwitched(labels[picked] ?? picked),
          );
        } catch (e) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(
            context,
            message: l10n.settingsSwitchFailed(e.toString()),
          );
        }
      },
    );
  }

  Widget _buildApiUrlSubtitle() {
    final l10n = AppLocalizations.of(context);
    final serversAsync = ref.watch(serversProvider);
    final currentUrl = ref.watch(baseUrlProvider);
    return serversAsync.when(
      data: (servers) {
        if (servers.isEmpty) return Text(l10n.settingsAccountUrlNotConfigured);
        final current = servers.firstWhere(
          (s) => s.url == currentUrl,
          orElse: () => servers.first,
        );
        final label = current.name.isNotEmpty ? current.name : current.url;
        return Text(l10n.settingsAccountUrlSummary(servers.length, label));
      },
      loading: () => Text(l10n.settingsAccountLoading),
      error: (_, _) => Text(l10n.commonLoadFailed),
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

    final l10n = AppLocalizations.of(context);
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
        Text(l10n.settingsAboutDesc1),
        const SizedBox(height: 8),
        Text(l10n.settingsAboutDesc2),
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
          label: l10n.settingsAboutGithubSemantics,
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
