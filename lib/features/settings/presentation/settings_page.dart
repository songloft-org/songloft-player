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
import '../../../shared/utils/responsive_snackbar.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';
import 'widgets/cache_manager.dart';
import '../../../features/jsplugin/presentation/widgets/jsplugin_manager.dart';
import 'widgets/scan_manager.dart';
import 'widgets/theme_selector.dart';
import 'widgets/frontend_upgrade_dialog.dart';
import 'widgets/upgrade_dialog.dart';
import 'providers/settings_provider.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 分组1: 外观设置
          _buildSectionCard(
            title: '外观设置',
            icon: Icons.palette_outlined,
            children: [
              const ListTile(
                leading: Icon(Icons.brightness_6),
                title: Text('主题模式'),
                subtitle: Text('选择应用的主题外观'),
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

          const SizedBox(height: 16),

          // 分组2: 音乐库管理
          _buildSectionCard(
            title: '音乐库管理',
            icon: Icons.library_music_outlined,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: ScanManager()),
              const Divider(height: 1),
              _buildAutoConvertTile(),
            ],
          ),

          const SizedBox(height: 16),

          // 分组4: 插件管理
          _buildSectionCard(
            title: '扩展',
            icon: Icons.extension_outlined,
            children: [const JSPluginManager()],
          ),

          const SizedBox(height: 16),

          // 分组: 缓存管理
          _buildSectionCard(
            title: '缓存管理',
            icon: Icons.storage_outlined,
            children: [const CacheManager()],
          ),

          const SizedBox(height: 16),

          // 分组: 电台 / 流媒体
          _buildSectionCard(
            title: '电台 / 流媒体',
            icon: Icons.cell_tower_outlined,
            children: [_buildHlsProxyTile()],
          ),

          const SizedBox(height: 16),

          // 分组: 数据管理
          _buildSectionCard(
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

          const SizedBox(height: 16),

          // 分组6: 系统
          _buildSectionCard(
            title: '系统',
            icon: Icons.settings_outlined,
            children: [
              _buildLogLevelTile(),
              const Divider(height: 1),
              _buildServerVersionTile(),
              if (!AppConfig.isEmbedded) ...[
                const Divider(height: 1),
                _buildFrontendUpdateTile(),
              ],
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

          // 分组7: 账户
          _buildSectionCard(
            title: '账户',
            icon: Icons.account_circle_outlined,
            children: [
              if (!AppConfig.isEmbedded) ...[
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('服务器'),
                  subtitle: _buildApiUrlSubtitle(),
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

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
        message: '导入完成: 新建歌单 $created, 合并歌单 $merged, '
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

  /// 构建服务端版本号 + 自动检查更新入口
  Widget _buildServerVersionTile() {
    final upgradeCheck = ref.watch(upgradeCheckProvider);

    return upgradeCheck.when(
      data: (check) {
        final currentVersion = check.currentVersion ?? '未知';
        final hasUpdate =
            check.hasUpdate && check.availableUpdates.isNotEmpty;
        final subtitle = hasUpdate
            ? '发现新版本: ${check.availableUpdates.first.version}'
            : '当前版本: $currentVersion (已是最新)';

        return ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('检查服务端更新 (仅 Docker 可升级)'),
          subtitle: Text(
            subtitle,
            style: hasUpdate
                ? TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
          trailing: hasUpdate
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
            title: Text('检查服务端更新 (仅 Docker 可升级)'),
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
            title: const Text('检查服务端更新 (仅 Docker 可升级)'),
            subtitle: const Text('检查更新失败'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpgradeDialog.show(context),
          ),
    );
  }

  /// 构建前端（客户端）更新检测入口
  Widget _buildFrontendUpdateTile() {
    final frontendCheck = ref.watch(frontendVersionCheckProvider);
    final versionDisplay = AppConfig.frontendVersionDisplay;

    return frontendCheck.when(
      data: (check) {
        final subtitle =
            check.hasUpdate
                ? '发现新版本: v${check.latestVersion}'
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
          onTap: () {
            if (check.hasUpdate) {
              FrontendUpgradeDialog.show(context, versionCheck: check);
            } else {
              ResponsiveSnackBar.show(
                context,
                message: '当前已是最新版本 $versionDisplay',
              );
            }
          },
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
            onTap: () => ref.invalidate(frontendVersionCheckProvider),
          ),
    );
  }

  /// HLS 电台后端代理开关
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
      onChanged: enabledAsync.isLoading
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

  /// 网络歌曲自动转本地开关
  Widget _buildAutoConvertTile() {
    final enabledAsync = ref.watch(autoConvertEnabledProvider);
    final enabled = enabledAsync.value ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.download_done_outlined),
      title: const Text('网络歌曲自动转为本地'),
      subtitle: const Text('网络歌曲缓存完成后,自动落地到音乐库,按歌单分目录存储'),
      value: enabled,
      onChanged: enabledAsync.isLoading
          ? null
          : (value) async {
              final dio = ref.read(dioProvider);
              try {
                await dio.put(
                  '${AppConfig.apiPrefix}/settings/auto-convert',
                  data: {'enabled': value},
                );
                ref.invalidate(autoConvertEnabledProvider);
                if (!mounted) return;
                ResponsiveSnackBar.show(
                  context,
                  message: value ? '已开启自动转换' : '已关闭自动转换',
                );
              } catch (e) {
                if (!mounted) return;
                ResponsiveSnackBar.showError(context, message: '保存失败: $e');
              }
            },
    );
  }

  /// 日志等级选择（运行时动态切换 slog 全局等级）
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
          builder: (ctx) => SimpleDialog(
            title: const Text('选择日志等级'),
            children: [
              RadioGroup<String>(
                groupValue: level,
                onChanged: (v) => Navigator.pop(ctx, v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: labels.entries
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容
          ...children,
        ],
      ),
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
    } catch (_) {
      // 忽略错误，使用默认版本号
    }

    if (!mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Songloft',
      applicationVersion: version,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icons/app_icon.png', width: 48, height: 48),
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
        InkWell(
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
      ],
    );
  }
}
