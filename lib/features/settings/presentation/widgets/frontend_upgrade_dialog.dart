import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/frontend_version_api.dart';
import '../providers/settings_provider.dart';

/// 前端（客户端）更新对话框
class FrontendUpgradeDialog extends ConsumerStatefulWidget {
  const FrontendUpgradeDialog({super.key});

  /// 显示前端更新对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const FrontendUpgradeDialog(),
    );
  }

  @override
  ConsumerState<FrontendUpgradeDialog> createState() =>
      _FrontendUpgradeDialogState();
}

class _FrontendUpgradeDialogState extends ConsumerState<FrontendUpgradeDialog> {
  bool _isChecking = true;
  String? _error;
  FrontendVersionCheck? _checkResult;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    // GitHub 代理来自「设置 → 网络设置」的全局配置
    final proxy = await ref.read(githubProxyProvider.future);
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _error = null;
      _checkResult = null;
    });

    try {
      final api = ref.read(frontendVersionApiProvider);
      final result = await api
          .checkUpdate(githubProxy: proxy.isNotEmpty ? proxy : null)
          .timeout(const Duration(seconds: 30));
      if (mounted) setState(() => _checkResult = result);
    } on TimeoutException {
      if (mounted) {
        setState(
          () =>
              _error =
                  AppLocalizations.of(
                    context,
                  ).settingsFrontendUpgradeCheckTimeout,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final ext = Theme.of(context).extension<SongloftThemeExtension>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ext.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AlertDialog(
          backgroundColor: ext.glassFill,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.cardRadius),
            side: BorderSide(color: ext.glassBorder, width: 0.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.phone_android),
              const SizedBox(width: 8),
              Text(l10n.settingsFrontendUpgradeTitle),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsiveDialogMaxWidth,
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 错误信息
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 正在检查
                  if (_isChecking)
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.settingsFrontendUpgradeChecking),
                        ],
                      ),
                    )
                  else if (_error != null)
                    const SizedBox.shrink()
                  else if (_checkResult != null)
                    _buildCheckResult(_checkResult!),
                ],
              ),
            ),
          ),
          actions: _buildActions(),
        ),
      ),
    );
  }

  Widget _buildCheckResult(FrontendVersionCheck check) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!check.hasUpdate) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(l10n.settingsFrontendUpgradeUpToDate),
            const SizedBox(height: 8),
            Text(
              l10n.settingsFrontendUpgradeCurrentVersion(
                AppConfig.frontendVersionDisplay,
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // 热更后行为异常时的退路：即便版本已是最新，也允许去下完整安装包覆盖安装。
            Text(
              l10n.settingsFrontendUpgradeReinstallHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 版本信息
        Text(
          l10n.settingsFrontendUpgradeCurrentVersion(
            AppConfig.frontendVersionDisplay,
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),

        // 新版本信息
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.new_releases, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.settingsFrontendUpgradeLatestVersion(
                    check.latestVersionDisplay,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 发布时间
        if (check.publishedAt != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.settingsFrontendUpgradePublishedAt(
              _formatDate(check.publishedAt!),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // 更新说明
        if (check.releaseNotes != null && check.releaseNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.settingsFrontendUpgradeReleaseNotes,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: check.releaseNotes!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodySmall,
                    listBullet: theme.textTheme.bodySmall,
                    blockSpacing: 8,
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 打开发布页。检查失败（[_checkResult] 为空）时回退到当前渠道的发布页常量，
  /// 保证 GitHub API 不可达时用户仍有下载完整安装包的退路。
  Future<void> _launchReleaseUrl() async {
    final proxy = ref.read(githubProxyProvider).value ?? '';
    final releaseUrl = _checkResult?.releaseUrl ?? '';
    final rawUrl =
        releaseUrl.isNotEmpty
            ? releaseUrl
            : AppConfig.frontendUpdateChannelReleaseUrl;
    final url = Uri.parse(FrontendVersionApi.applyProxy(rawUrl, proxy));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  List<Widget> _buildActions() {
    final l10n = AppLocalizations.of(context);
    if (_isChecking) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonCancel),
        ),
      ];
    }

    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsFrontendUpgradeClose),
        ),
        _buildDownloadFullButton(l10n),
        FilledButton(
          onPressed: _checkUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonRetry),
        ),
      ];
    }

    if (_checkResult != null && _checkResult!.hasUpdate) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsFrontendUpgradeLater),
        ),
        FilledButton.icon(
          onPressed: _launchReleaseUrl,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.settingsFrontendUpgradeGoDownload),
        ),
      ];
    }

    if (_checkResult != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsFrontendUpgradeClose),
        ),
        _buildDownloadFullButton(l10n),
      ];
    }

    return [];
  }

  /// 「下载完整安装包」：已是最新 / 检查失败时的退路，用于热更异常后覆盖安装。
  /// 次要按钮层级，不抢「重新检查」的主按钮位。
  Widget _buildDownloadFullButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: _launchReleaseUrl,
      style: OutlinedButton.styleFrom(
        minimumSize: context.responsiveButtonMinSize,
      ),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(l10n.settingsFrontendUpgradeDownloadFull),
    );
  }
}
