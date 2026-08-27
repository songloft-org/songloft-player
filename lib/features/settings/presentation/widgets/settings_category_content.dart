import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/base_url_provider.dart';
import '../../../../core/network/insecure_tls_provider.dart';
import '../../../../core/network/servers_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/updater/patch_update_dialog.dart';
import '../../../../core/updater/patch_update_service.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/utils/web_cache_clearer.dart' as web_cache;
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../desktop_lyric/desktop_lyric_font_size.dart';
import '../../../player/domain/mini_player_controls.dart';
import '../../../player/presentation/providers/mini_player_controls_provider.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';
import '../../../jsplugin/data/jsplugin_api.dart';
import '../../../jsplugin/presentation/providers/jsplugin_provider.dart';
import '../../../jsplugin/presentation/widgets/jsplugin_manager.dart';
import '../../../jsplugin/presentation/widgets/plugin_icon.dart';
import '../../../../core/backend/run_mode_provider.dart';
import '../../data/log_export_service.dart';
import '../../data/settings_api.dart';
import '../../data/upgrade_api.dart';
import 'cache_manager.dart';
import 'home_grid_selector.dart';
import 'metadata_refresh_manager.dart';
import 'scan_manager.dart';
import 'section_card.dart';
import 'settings_master_detail.dart';
import 'theme_selector.dart';
import 'theme_pack_manager.dart';
import 'language_selector.dart';
import '../../../../l10n/app_localizations.dart';
import 'frontend_upgrade_dialog.dart';
import 'github_proxy_dialog.dart';
import 'upgrade_dialog.dart';
import '../providers/settings_provider.dart';

/// 设置分类数量（与 [buildSettingsCategories] 返回长度一致）。
/// 供 `/settings/category/:index` 路由做越界防御，避免在 redirect 里依赖 l10n。
const int settingsCategoryCount = 9;

/// 设置分类列表（外观/播放/音乐库/扩展/缓存/网络/数据/关于/账户）。
///
/// 桌面/移动 [SettingsPage] 共用同一来源，避免分类漂移。
List<SettingsCategory> buildSettingsCategories(AppLocalizations l10n) => [
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

/// 服务器信息卡片（主从布局 header）。
class SettingsServerInfoCard extends ConsumerWidget {
  const SettingsServerInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUrl = ref.watch(baseUrlProvider);
    final serverVersionAsync = ref.watch(serverVersionProvider);
    final versionInfo = serverVersionAsync.value;
    String? versionLabel;
    if (versionInfo != null) {
      final base =
          versionInfo.version == 'dev'
              ? l10n.settingsDevVersion
              : 'v${versionInfo.version}';
      final details = <String>[];
      if (versionInfo.gitCommit != null) {
        details.add(versionInfo.gitCommit!);
      }
      if (versionInfo.buildTime != null) {
        details.add(versionInfo.buildTime!);
      }
      versionLabel = details.isEmpty ? base : '$base (${details.join(' · ')})';
    }

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
}

/// 单个设置分类的内容（SectionCard 列表）。桌面/移动主从右栏共用。
class SettingsCategoryContent extends ConsumerStatefulWidget {
  /// 分类索引（对应 [buildSettingsCategories] 的顺序）。
  final int index;

  const SettingsCategoryContent({super.key, required this.index});

  @override
  ConsumerState<SettingsCategoryContent> createState() =>
      _SettingsCategoryContentState();
}

class _SettingsCategoryContentState
    extends ConsumerState<SettingsCategoryContent> {
  static const int _maxTabs = 12;
  static const int _fixedTabs = 2;

  bool _exportingLogs = false;

  /// 「检查客户端更新」正在查热更补丁（查完才可能弹对话框，期间 tile 显示 spinner）。
  bool _checkingPatch = false;

  @override
  Widget build(BuildContext context) {
    final items = switch (widget.index) {
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
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: Text(l10n.themePackTitle),
            subtitle: Text(l10n.themePackSubtitle),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ThemePackManager(),
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
        title: l10n.settingsFontScaleTitle,
        icon: Icons.format_size_outlined,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _FontScaleSelector(),
          ),
        ],
      ),
      SectionCard(
        title: l10n.settingsHomeGridTitle,
        icon: Icons.grid_view_outlined,
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: HomeGridSelector(),
          ),
        ],
      ),
      SectionCard(
        title: l10n.settingsMenuTitle,
        icon: Icons.tab_outlined,
        children: [
          // 歌单已并入曲库，不再作为独立底部 tab；此处仅保留「曲库」开关。
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
    final autoPlayOnLaunch = ref.watch(autoPlayOnLaunchProvider);
    final miniPlayerControls = ref.watch(miniPlayerControlsProvider);
    final miniPlayerControlsLabels = {
      MiniPlayerControls.playOnly: l10n.settingsMiniPlayerControlsPlayOnly,
      MiniPlayerControls.prevNext: l10n.settingsMiniPlayerControlsPrevNext,
      MiniPlayerControls.prevNextMode:
          l10n.settingsMiniPlayerControlsPrevNextMode,
    };
    final autoEnterLyrics = ref.watch(autoEnterLyricsOnLaunchProvider);
    final lyricInTitle = ref.watch(notificationLyricInTitleProvider);
    final desktopLyricEnabled = ref.watch(desktopLyricEnabledProvider);
    final desktopLyricLocked = ref.watch(desktopLyricLockedProvider);
    final desktopLyricFontSize = ref.watch(desktopLyricFontSizeProvider);
    final desktopLyricOpacity = ref.watch(desktopLyricOpacityProvider);
    final fontSizeLabels = {
      DesktopLyricFontSize.small: l10n.settingsDesktopLyricFontSizeSmall,
      DesktopLyricFontSize.medium: l10n.settingsDesktopLyricFontSizeMedium,
      DesktopLyricFontSize.large: l10n.settingsDesktopLyricFontSizeLarge,
    };
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
          const Divider(height: 1),
          _buildVolumeNormalizeTile(),
          const Divider(height: 1),
          // 打开客户端后自动播放（纯本地设置）
          SwitchListTile(
            secondary: const Icon(Icons.play_arrow_outlined),
            title: Text(l10n.settingsAutoPlayOnLaunchTitle),
            subtitle: Text(l10n.settingsAutoPlayOnLaunchDesc),
            value: autoPlayOnLaunch,
            onChanged: (v) {
              ref.read(autoPlayOnLaunchProvider.notifier).setEnabled(v);
            },
          ),
          const Divider(height: 1),
          // 底部播放条显示哪些按钮（纯本地设置，songloft-org/songloft-player#25）
          ListTile(
            leading: const Icon(Icons.skip_next_outlined),
            title: Text(l10n.settingsMiniPlayerControlsTitle),
            subtitle: Text(
              miniPlayerControlsLabels[miniPlayerControls] ??
                  l10n.settingsMiniPlayerControlsPrevNext,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDialog<MiniPlayerControls>(
                context: context,
                builder:
                    (ctx) => SimpleDialog(
                      title: Text(l10n.settingsMiniPlayerControlsDialogTitle),
                      children: [
                        RadioGroup<MiniPlayerControls>(
                          groupValue: miniPlayerControls,
                          onChanged: (v) => Navigator.pop(ctx, v),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                MiniPlayerControls.values
                                    .map(
                                      (mode) =>
                                          RadioListTile<MiniPlayerControls>(
                                            title: Text(
                                              miniPlayerControlsLabels[mode] ??
                                                  '',
                                            ),
                                            value: mode,
                                          ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
              );
              if (picked == null) return;
              ref.read(miniPlayerControlsProvider.notifier).setControls(picked);
            },
          ),
          const Divider(height: 1),
          // 打开客户端后自动进入全屏歌词（纯本地设置，按屏幕分辨率进入对应界面）
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_outlined),
            title: Text(l10n.settingsAutoEnterLyricsOnLaunchTitle),
            subtitle: Text(l10n.settingsAutoEnterLyricsOnLaunchDesc),
            value: autoEnterLyrics,
            onChanged: (v) {
              ref.read(autoEnterLyricsOnLaunchProvider.notifier).setEnabled(v);
            },
          ),
          const Divider(height: 1),
          // 系统媒体通知里歌词的显示位置（纯本地设置）
          SwitchListTile(
            secondary: const Icon(Icons.subtitles_outlined),
            title: Text(l10n.settingsNotificationLyricInTitleTitle),
            subtitle: Text(l10n.settingsNotificationLyricInTitleDesc),
            value: lyricInTitle,
            onChanged: (v) {
              ref.read(notificationLyricInTitleProvider.notifier).setEnabled(v);
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
          // 悬浮歌词窗口（Windows 桌面窗口 / Android 系统悬浮窗，songloft-org/songloft#318）
          if (PlatformUtils.isWindows || PlatformUtils.isAndroid) ...[
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.lyrics_outlined),
              title: Text(l10n.settingsDesktopLyricTitle),
              subtitle: Text(l10n.settingsDesktopLyricDesc),
              value: desktopLyricEnabled,
              onChanged: (v) {
                ref.read(desktopLyricEnabledProvider.notifier).setEnabled(v);
              },
            ),
            if (desktopLyricEnabled) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: Text(l10n.settingsDesktopLyricLockTitle),
                subtitle: Text(l10n.settingsDesktopLyricLockDesc),
                value: desktopLyricLocked,
                onChanged: (v) {
                  ref.read(desktopLyricLockedProvider.notifier).setLocked(v);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.format_size),
                title: Text(l10n.settingsDesktopLyricFontSizeTitle),
                trailing: SegmentedButton<DesktopLyricFontSize>(
                  segments:
                      DesktopLyricFontSize.values
                          .map(
                            (size) => ButtonSegment(
                              value: size,
                              label: Text(fontSizeLabels[size] ?? ''),
                            ),
                          )
                          .toList(),
                  selected: {desktopLyricFontSize},
                  onSelectionChanged: (selection) {
                    ref
                        .read(desktopLyricFontSizeProvider.notifier)
                        .setFontSize(selection.first);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.opacity),
                title: Text(l10n.settingsDesktopLyricOpacityTitle),
                subtitle: Slider(
                  min: 0.0,
                  max: 0.8,
                  divisions: 8,
                  value: desktopLyricOpacity,
                  label: '${(desktopLyricOpacity * 100).round()}%',
                  onChanged: (v) {
                    ref
                        .read(desktopLyricOpacityProvider.notifier)
                        .setOpacity(v);
                  },
                ),
              ),
            ],
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
          // 刻意没有「渲染引擎」开关：引擎由每个插件的 plugin.json 声明
          // （songloft-org/songloft#341），插件作者才知道自家页面在哪个引擎下
          // 正常，用户级全局开关只会把「某个插件坏了」放大成「所有插件一起坏」。
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
          _buildGithubProxyTile(),
          const Divider(height: 1),
          _buildHlsProxyTile(),
          const Divider(height: 1),
          _buildProxyAllowlistTile(),
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
          if (!kIsWeb && !AppConfig.isEmbedded) ...[
            const Divider(height: 1),
            _buildFrontendUpdateTile(),
          ],
          if (!kIsWeb) ...[
            const Divider(height: 1),
            _buildAutoUpdateCheckTile(),
          ],
          const Divider(height: 1),
          _buildLogLevelTile(),
          const Divider(height: 1),
          _buildExportLogsTile(),
          if (kIsWeb) ...[
            const Divider(height: 1),
            _buildWebDebugConsoleTile(),
          ],
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
          // 开源许可（songloft-org/songloft#341）。客户端二进制链接 GPL-3.0-only
          // 的 WebF，整体按 GPL-3.0 分发，GPLv3 §4/§5 要求随附许可全文与源码获取
          // 方式，这个入口是 App 内的履行点。刻意与「关于」并列而不是塞进关于对话框
          // ——许可全文与依赖清单都是整页内容，对话框放不下。
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLicensesTitle),
            subtitle: Text(l10n.settingsLicensesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.licenses),
          ),
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

  // ── 业务逻辑方法 ──

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

        return _clientUpdateTile(
          l10n: l10n,
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
        );
      },
      // loading 也走公共外壳并保留 onTap:热更检查与 frontendVersionCheckProvider
      // 毫无依赖,被墙时那个 GitHub 请求可能挂满 dio 超时,期间正是用户最需要手动查
      // 热更的时候 —— 不能让入口在这段时间里是死的。
      loading:
          () => _clientUpdateTile(
            l10n: l10n,
            subtitle: Text(l10n.settingsCurrentVersion(versionDisplay)),
            trailing: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (_, _) => _clientUpdateTile(
            l10n: l10n,
            subtitle: Text(l10n.settingsCurrentVersion(versionDisplay)),
            trailing: const Icon(Icons.chevron_right),
          ),
    );
  }

  /// 「检查客户端更新」tile 的公共外壳:统一承担 [_checkingPatch] 的 spinner/禁用态,
  /// 让 data / error 两个分支只负责各自的 subtitle 与 trailing。
  Widget _clientUpdateTile({
    required AppLocalizations l10n,
    required Widget subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      leading: const Icon(Icons.phone_android),
      title: Text(l10n.settingsCheckClientUpdate),
      subtitle: subtitle,
      trailing:
          _checkingPatch
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : trailing,
      enabled: !_checkingPatch,
      onTap: _onCheckClientUpdate,
    );
  }

  /// 手动检查客户端更新:先查 Android 热更补丁,没有再落到整包更新对话框。
  ///
  /// `manual: true` 让 [PatchUpdateDialog.maybeShow] 跳过启动节流与「忽略此版本」
  /// 名单 —— 用户主动点这里就是主动求更新。无补丁（含非 Android、检查失败）时交给
  /// [FrontendUpgradeDialog]，它自带「正在检查 / 已是最新 / 检查失败」三态，所以这里
  /// 不需要额外的 snackbar 反馈。
  Future<void> _onCheckClientUpdate() async {
    if (_checkingPatch) return;

    // 非 Android 永远不可能有补丁,直接开整包对话框 —— 省掉构造两个 service、
    // 跑 runMode ensureLoaded、以及闪一下注定无结果的 spinner。
    // （注意不是为了省 githubProxy 请求:本 tile watch 的 frontendVersionCheckProvider
    // 自己就 await 了 githubProxyProvider,用户能点时那个值早已解析并缓存。）
    if (PatchUpdateService.isPlatformSupported) {
      setState(() => _checkingPatch = true);
      try {
        final shown = await PatchUpdateDialog.maybeShow(
          context,
          ref,
          manual: true,
        );
        if (shown) return;
      } catch (e) {
        debugPrint('[Settings] 手动热更检查失败: $e'); // 落整包对话框,由它报错
      } finally {
        if (mounted) setState(() => _checkingPatch = false);
      }
    }

    if (mounted) FrontendUpgradeDialog.show(context);
  }

  /// 「启动时自动检查更新」开关。关掉后启动路径完全不打网络,只能从上面那条
  /// 「检查客户端更新」手动触发。
  Widget _buildAutoUpdateCheckTile() {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(autoUpdateCheckProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.update_outlined),
      title: Text(l10n.settingsAutoUpdateCheckTitle),
      // 节流窗口从常量取,不写死在文案里 —— 否则改 kPatchCheckThrottle 后 UI 会说谎
      subtitle: Text(
        l10n.settingsAutoUpdateCheckSubtitle(kPatchCheckThrottle.inHours),
      ),
      value: enabled,
      onChanged:
          (value) =>
              ref.read(autoUpdateCheckProvider.notifier).setEnabled(value),
    );
  }

  Widget _buildVolumeNormalizeTile() {
    final l10n = AppLocalizations.of(context);
    final enabledAsync = ref.watch(volumeNormalizeProvider);
    final setting = enabledAsync.value;
    final enabled = setting?.enabled ?? false;

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.graphic_eq_outlined),
          title: Text(l10n.settingsVolumeNormalizeTitle),
          subtitle: Text(l10n.settingsVolumeNormalizeSubtitle),
          value: enabled,
          onChanged:
              enabledAsync.isLoading
                  ? null
                  : (value) async {
                    try {
                      await ref
                          .read(volumeNormalizeProvider.notifier)
                          .setEnabled(value);
                      if (!mounted) return;
                      ResponsiveSnackBar.show(
                        context,
                        message:
                            value
                                ? l10n.settingsVolumeNormalizeEnabled
                                : l10n.settingsVolumeNormalizeDisabled,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ResponsiveSnackBar.showError(
                        context,
                        message: l10n.settingsSaveFailed(e.toString()),
                      );
                    }
                  },
        ),
        // 开启时展开目标响度（LUFS）编辑项；关闭时隐藏。
        if (enabled)
          ListTile(
            enabled: !enabledAsync.isLoading,
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.settingsVolumeNormalizeLoudnessTitle),
            subtitle: Text(l10n.settingsVolumeNormalizeLoudnessSubtitle),
            trailing: Text(
              setting == null ? '-16' : setting.loudness.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap:
                enabledAsync.isLoading
                    ? null
                    : () =>
                        _editVolumeNormalizeLoudness(setting?.loudness ?? -16),
          ),
      ],
    );
  }

  /// 弹出对话框编辑目标响度（LUFS）。校验范围 [-40, -5]，非法值提示。
  Future<void> _editVolumeNormalizeLoudness(double current) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: current.toStringAsFixed(1));

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final v = double.tryParse(controller.text.trim());
              if (v == null) {
                setState(
                  () => errorText = l10n.settingsVolumeNormalizeLoudnessInvalid,
                );
                return;
              }
              if (v < -40 || v > -5) {
                setState(
                  () => errorText = l10n.settingsVolumeNormalizeLoudnessInvalid,
                );
                return;
              }
              if (!context.mounted) return;
              Navigator.of(context).pop(v);
            }

            return AlertDialog(
              title: Text(l10n.settingsVolumeNormalizeLoudnessTitle),
              content: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  hintText: '-16',
                  helperText: 'LUFS',
                  errorText: errorText,
                ),
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                TextButton(onPressed: submit, child: Text(l10n.settingsSave)),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (result == null) return;
    try {
      await ref.read(volumeNormalizeProvider.notifier).setLoudness(result);
      if (!mounted) return;
      ResponsiveSnackBar.show(
        context,
        message: l10n.settingsVolumeNormalizeLoudnessSaved(
          result.toStringAsFixed(1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsSaveFailed(e.toString()),
      );
    }
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

  Widget _buildProxyAllowlistTile() {
    final l10n = AppLocalizations.of(context);
    final allowlistAsync = ref.watch(proxyPrivateAllowlistProvider);
    final allowlist = allowlistAsync.value ?? const <String>[];

    return ListTile(
      leading: const Icon(Icons.lan_outlined),
      title: Text(l10n.settingsProxyAllowlistTitle),
      subtitle: Text(
        allowlist.isEmpty
            ? l10n.settingsProxyAllowlistEmpty
            : l10n.settingsProxyAllowlistCount(allowlist.length),
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: !allowlistAsync.isLoading,
      onTap: () async {
        final controller = TextEditingController(text: allowlist.join('\n'));
        final result = await showDialog<List<String>>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(l10n.settingsProxyAllowlistTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsProxyAllowlistDialogDesc),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: l10n.settingsProxyAllowlistLabel,
                        hintText: '192.168.1.0/24\n10.0.0.5',
                        helperText: l10n.settingsProxyAllowlistHelper,
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final entries =
                          controller.text
                              .split('\n')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                      Navigator.pop(ctx, entries);
                    },
                    child: Text(l10n.settingsSave),
                  ),
                ],
              ),
        );
        if (result == null) return;
        try {
          await ref
              .read(proxyPrivateAllowlistProvider.notifier)
              .setValue(result);
          if (!mounted) return;
          ResponsiveSnackBar.show(
            context,
            message: l10n.settingsProxyAllowlistSaved,
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

  Widget _buildWebDebugConsoleTile() {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(webDebugConsoleProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.bug_report_outlined),
      title: Text(l10n.settingsWebDebugConsoleTitle),
      subtitle: Text(l10n.settingsWebDebugConsoleSubtitle),
      value: enabled,
      onChanged: (value) async {
        await ref.read(webDebugConsoleProvider.notifier).setEnabled(value);
        if (!mounted) return;
        ResponsiveSnackBar.show(
          context,
          message:
              value
                  ? l10n.settingsWebDebugConsoleEnabled
                  : l10n.settingsWebDebugConsoleDisabled,
        );
        await Future.delayed(const Duration(milliseconds: 500));
        web_cache.reloadPage();
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
      subtitle: Text(
        proxy.isEmpty ? l10n.settingsHttpProxyNotConfigured : proxy,
      ),
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

  Widget _buildGithubProxyTile() {
    final l10n = AppLocalizations.of(context);
    final proxyAsync = ref.watch(githubProxyProvider);
    final proxy = proxyAsync.value ?? '';

    return ListTile(
      leading: const Icon(Icons.bolt_outlined),
      title: Text(l10n.settingsGithubProxyTitle),
      subtitle: Text(proxy.isEmpty ? l10n.githubProxyDirect : proxy),
      trailing: const Icon(Icons.chevron_right),
      enabled: !proxyAsync.isLoading,
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (_) => GithubProxyDialog(current: proxy),
        );
        if (result == null || result == proxy) return;
        await ref.read(githubProxyProvider.notifier).setValue(result);
        if (!mounted) return;
        ResponsiveSnackBar.show(
          context,
          message:
              result.isEmpty
                  ? l10n.settingsGithubProxyCleared
                  : l10n.settingsGithubProxySet(result),
        );
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

  // 导出前后端日志（脱敏后打包 zip 分享），供用户提交 issue 时附上。
  Widget _buildExportLogsTile() {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(l10n.settingsExportLogsTitle),
      subtitle: Text(l10n.settingsExportLogsSubtitle),
      trailing:
          _exportingLogs
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.chevron_right),
      enabled: !_exportingLogs,
      onTap: () async {
        if (_exportingLogs) return;
        setState(() => _exportingLogs = true);
        try {
          final result = await ref
              .read(logExportServiceProvider)
              .exportAndShare(
                shareSubject: l10n.settingsExportLogsShareSubject,
              );
          if (!mounted) return;
          ResponsiveSnackBar.show(
            context,
            message:
                result.hasBackend
                    ? l10n.settingsExportLogsSuccess
                    : l10n.settingsExportLogsSuccessNoBackend,
          );
        } catch (e) {
          if (!mounted) return;
          ResponsiveSnackBar.showError(
            context,
            message: l10n.settingsExportLogsFailed(e.toString()),
          );
        } finally {
          if (mounted) setState(() => _exportingLogs = false);
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
    String? buildTime;

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
      final built = data['build_time'] as String?;
      if (built != null && built != 'unknown' && built.isNotEmpty) {
        buildTime = built;
      }
    } catch (_) {}

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    // 与设置页顶部版本标签一致：开发版显示「开发版」、正式版显示 vX.Y.Z，
    // 两者都在后面附上构建时间（缺失时省略）。
    final versionBase =
        version == 'dev' ? l10n.settingsDevVersion : 'v$version';
    final versionLabel =
        buildTime != null ? '$versionBase ($buildTime)' : versionBase;
    showAboutDialog(
      context: context,
      applicationName: 'Songloft',
      applicationVersion: versionLabel,
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

class _FontScaleSelector extends ConsumerWidget {
  static const _scales = [0.85, 1.0, 1.15, 1.3];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(fontScaleProvider);
    final labels = [
      l10n.settingsFontScaleSmall,
      l10n.settingsFontScaleDefault,
      l10n.settingsFontScaleLarge,
      l10n.settingsFontScaleExtraLarge,
    ];

    return SegmentedButton<double>(
      segments: [
        for (var i = 0; i < _scales.length; i++)
          ButtonSegment(value: _scales[i], label: Text(labels[i])),
      ],
      selected: {current},
      onSelectionChanged: (selected) {
        ref.read(fontScaleProvider.notifier).setScale(selected.first);
      },
    );
  }
}
