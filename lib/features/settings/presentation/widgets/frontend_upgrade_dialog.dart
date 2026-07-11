import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/constants/github_proxy.dart';
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

  int _selectedProxyIndex = 0;
  final TextEditingController _customProxyController = TextEditingController();

  String _lastCheckedProxy = '';

  String get _effectiveProxy {
    if (_selectedProxyIndex == -1) {
      return _customProxyController.text.trim();
    }
    if (_selectedProxyIndex >= 0 &&
        _selectedProxyIndex < kGithubProxyPresets.length) {
      return kGithubProxyPresets[_selectedProxyIndex].value;
    }
    return '';
  }

  bool get _proxyChanged => _effectiveProxy != _lastCheckedProxy;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  @override
  void dispose() {
    _customProxyController.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final proxy = _effectiveProxy;
    setState(() {
      _isChecking = true;
      _error = null;
      _checkResult = null;
      _lastCheckedProxy = proxy;
    });

    try {
      final api = ref.read(frontendVersionApiProvider);
      final result = await api
          .checkUpdate(githubProxy: proxy.isNotEmpty ? proxy : null)
          .timeout(const Duration(seconds: 15));
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

    return AlertDialog(
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
          maxHeight: MediaQuery.of(context).size.height * 0.6,
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

              // GitHub 代理选择
              _buildProxySelector(theme, colorScheme),

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
    );
  }

  Widget _buildProxySelector(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsFrontendUpgradeGithubProxy,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _selectedProxyIndex,
            onChanged: (value) {
              if (value != null) setState(() => _selectedProxyIndex = value);
            },
            child: Column(
              children: [
                ...List.generate(kGithubProxyPresets.length, (index) {
                  final proxy = kGithubProxyPresets[index];
                  return RadioListTile<int>(
                    title: Text(
                      proxy.value.isEmpty ? l10n.githubProxyDirect : proxy.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: index,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }),
                RadioListTile<int>(
                  title: Text(
                    l10n.settingsFrontendUpgradeCustomProxy,
                    style: theme.textTheme.bodyMedium,
                  ),
                  value: -1,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (_selectedProxyIndex == -1)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: TextField(
                controller: _customProxyController,
                decoration: InputDecoration(
                  hintText: 'https://your-proxy.com/',
                  helperText: l10n.settingsFrontendUpgradeProxyHelper,
                  helperMaxLines: 2,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Divider(height: 24),
        ],
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

  Future<void> _launchReleaseUrl() async {
    if (_checkResult == null) return;
    final proxy = _effectiveProxy;
    final rawUrl =
        _checkResult!.releaseUrl.isNotEmpty
            ? _checkResult!.releaseUrl
            : AppConfig.frontendReleasesUrl;
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
        if (_proxyChanged)
          FilledButton(
            onPressed: _checkUpdate,
            style: FilledButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: Text(l10n.settingsFrontendUpgradeRecheck),
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
        if (_proxyChanged)
          OutlinedButton(
            onPressed: _checkUpdate,
            style: OutlinedButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: Text(l10n.settingsFrontendUpgradeRecheck),
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
        if (_proxyChanged)
          FilledButton(
            onPressed: _checkUpdate,
            style: FilledButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: Text(l10n.settingsFrontendUpgradeRecheck),
          ),
      ];
    }

    return [];
  }
}
