import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/theme/responsive.dart';
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
  static const List<_ProxyOption> _presetProxies = [
    _ProxyOption(label: '直连 (不使用代理)', value: ''),
    _ProxyOption(label: 'ghproxy.com', value: 'https://ghproxy.com/'),
    _ProxyOption(label: 'ghfast.top', value: 'https://ghfast.top/'),
    _ProxyOption(label: 'gh.con.sh', value: 'https://gh.con.sh/'),
    _ProxyOption(
      label: 'mirror.ghproxy.com',
      value: 'https://mirror.ghproxy.com/',
    ),
  ];

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
        _selectedProxyIndex < _presetProxies.length) {
      return _presetProxies[_selectedProxyIndex].value;
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
      if (mounted) setState(() => _error = '检查更新超时，请尝试切换代理后重试');
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

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.phone_android),
          SizedBox(width: 8),
          Text('客户端更新'),
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
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在检查更新...'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GitHub 代理', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _selectedProxyIndex,
            onChanged: (value) {
              if (value != null) setState(() => _selectedProxyIndex = value);
            },
            child: Column(
              children: [
                ...List.generate(_presetProxies.length, (index) {
                  final proxy = _presetProxies[index];
                  return RadioListTile<int>(
                    title: Text(proxy.label, style: theme.textTheme.bodyMedium),
                    value: index,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }),
                RadioListTile<int>(
                  title: Text('自定义代理', style: theme.textTheme.bodyMedium),
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
                decoration: const InputDecoration(
                  hintText: 'https://your-proxy.com/',
                  helperText: '输入代理地址，如 https://ghproxy.com/',
                  helperMaxLines: 2,
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
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

    if (!check.hasUpdate) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('已是最新版本'),
            const SizedBox(height: 8),
            Text(
              '当前版本: ${AppConfig.frontendVersionDisplay}',
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
          '当前版本: ${AppConfig.frontendVersionDisplay}',
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
                  '最新版本: ${check.latestVersionDisplay}',
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
            '发布时间: ${_formatDate(check.publishedAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // 更新说明
        if (check.releaseNotes != null && check.releaseNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('更新说明:', style: theme.textTheme.titleSmall),
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
    if (_isChecking) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('取消'),
        ),
        if (_proxyChanged)
          FilledButton(
            onPressed: _checkUpdate,
            style: FilledButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: const Text('重新检查'),
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
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _checkUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('重试'),
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
          child: const Text('稍后'),
        ),
        if (_proxyChanged)
          OutlinedButton(
            onPressed: _checkUpdate,
            style: OutlinedButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: const Text('重新检查'),
          ),
        FilledButton.icon(
          onPressed: _launchReleaseUrl,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('前往下载'),
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
          child: const Text('关闭'),
        ),
        if (_proxyChanged)
          FilledButton(
            onPressed: _checkUpdate,
            style: FilledButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: const Text('重新检查'),
          ),
      ];
    }

    return [];
  }
}

class _ProxyOption {
  final String label;
  final String value;

  const _ProxyOption({required this.label, required this.value});
}
