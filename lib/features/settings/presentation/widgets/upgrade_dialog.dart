import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/upgrade_api.dart';
import '../providers/settings_provider.dart';

/// 升级对话框
class UpgradeDialog extends ConsumerStatefulWidget {
  const UpgradeDialog({super.key});

  /// 显示升级对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpgradeDialog(),
    );
  }

  @override
  ConsumerState<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends ConsumerState<UpgradeDialog> {
  bool _isChecking = true;
  bool _isStarting = false;
  bool _isResetting = false;
  bool _isUploading = false;
  String? _error;
  UpgradeCheck? _checkResult;

  /// 当前选中的版本类型索引（在 availableUpdates 列表中的索引）
  int _selectedVersionIndex = 0;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 延迟调用，避免在 initState 中访问 inherited widget
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkUpgrade();
    });
  }

  Future<void> _checkUpgrade() async {
    // GitHub 代理来自「设置 → 网络设置」的全局配置
    final proxy = await ref.read(githubProxyProvider.future);
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _error = null;
      _checkResult = null;
    });

    try {
      final upgradeApi = ref.read(upgradeApiProvider);
      final result = await upgradeApi
          .checkUpgrade(githubProxy: proxy.isNotEmpty ? proxy : null)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() => _checkResult = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context).settingsUpgradeCheckTimeout,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(
                context,
              ).settingsUpgradeCheckFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// 获取当前选中的版本信息
  UpdateVersionInfo? get _selectedVersion {
    if (_checkResult == null || _checkResult!.availableUpdates.isEmpty) {
      return null;
    }
    if (_selectedVersionIndex >= 0 &&
        _selectedVersionIndex < _checkResult!.availableUpdates.length) {
      return _checkResult!.availableUpdates[_selectedVersionIndex];
    }
    return _checkResult!.availableUpdates.first;
  }

  String _formatCurrentVersion(UpgradeCheck check) {
    final l10n = AppLocalizations.of(context);
    final versionText = check.currentVersion ?? l10n.commonUnknown;
    final details = <String>[];
    if (check.currentChannel == 'dev') {
      details.add(l10n.settingsUpgradeChannelDev);
    } else if (check.currentChannel == 'stable') {
      details.add(l10n.settingsUpgradeChannelStable);
    }
    if (check.currentBuildType != null && check.currentBuildType!.isNotEmpty) {
      details.add(check.currentBuildType!);
    }
    return details.isEmpty
        ? versionText
        : l10n.settingsUpgradeVersionWithDetails(
          versionText,
          details.join(', '),
        );
  }

  Future<void> _startUpgrade() async {
    final version = _selectedVersion;
    if (version == null) return;

    final proxy = await ref.read(githubProxyProvider.future);
    if (!mounted) return;
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await ref
          .read(upgradeProgressProvider.notifier)
          .startUpgrade(
            versionType: version.type,
            githubProxy: proxy.isNotEmpty ? proxy : null,
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () =>
            _error = AppLocalizations.of(
              context,
            ).settingsUpgradeStartFailed('$e'),
      );
    } finally {
      setState(() => _isStarting = false);
    }
  }

  Future<void> _resetToBaseImage() async {
    final l10n = AppLocalizations.of(context);
    // 二次确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsUpgradeConfirmReset),
            content: Text(l10n.settingsUpgradeConfirmResetContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.settingsUpgradeConfirmReset),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isResetting = true;
      _error = null;
    });

    try {
      await ref.read(upgradeProgressProvider.notifier).resetToBaseImage();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(
                context,
              ).settingsUpgradeResetFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final upgradeProgress = ref.watch(upgradeProgressProvider);
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
              const Icon(Icons.system_update),
              const SizedBox(width: 8),
              Text(l10n.settingsUpgradeTitle),
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
                          Text(l10n.settingsUpgradeChecking),
                        ],
                      ),
                    )
                  // 正在升级
                  else if (upgradeProgress.isUpgrading)
                    _buildUpgradeProgress(upgradeProgress)
                  // 升级完成
                  else if (upgradeProgress.isCompleted)
                    _buildUpgradeCompleted()
                  // 升级出错
                  else if (upgradeProgress.isError)
                    _buildUpgradeError(upgradeProgress)
                  // 本地捕获的错误（如 API 返回 403）- 错误信息已在顶部显示
                  else if (_error != null)
                    const SizedBox.shrink()
                  // 显示检查结果
                  else if (_checkResult != null)
                    _buildCheckResult(_checkResult!),
                ],
              ),
            ),
          ),
          actions: _buildActions(upgradeProgress),
        ),
      ),
    );
  }

  Widget _buildCheckResult(UpgradeCheck check) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!check.hasUpdate) {
      final currentVersion = _formatCurrentVersion(check);
      return Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(l10n.settingsUpgradeUpToDate),
            const SizedBox(height: 8),
            Text(
              l10n.settingsUpgradeCurrentVersion(currentVersion),
              style: theme.textTheme.bodySmall,
            ),
            // 仅 Docker 环境显示回退按钮
            if (check.isDocker) ...[
              const SizedBox(height: 16),
              _buildResetButton(theme),
            ],
          ],
        ),
      );
    }

    final selectedVersion = _selectedVersion;
    final currentVersion = _formatCurrentVersion(check);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前版本
        Text(
          l10n.settingsUpgradeCurrentVersion(currentVersion),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),

        // 版本选择（多个可用更新时显示，仅 Docker 环境）
        if (check.isDocker && check.availableUpdates.length > 1) ...[
          Text(
            l10n.settingsUpgradeSelectVersion,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _selectedVersionIndex,
            onChanged: (value) {
              if (value != null) setState(() => _selectedVersionIndex = value);
            },
            child: Column(
              children: [
                ...List.generate(check.availableUpdates.length, (index) {
                  final update = check.availableUpdates[index];
                  return RadioListTile<int>(
                    title: Text(
                      '${update.label} (${update.version})',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle:
                        update.buildTime != null
                            ? Text(
                              l10n.settingsUpgradeBuildTime(
                                '${update.buildTime}',
                              ),
                              style: theme.textTheme.bodySmall,
                            )
                            : null,
                    value: index,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 选中版本的详细信息
        if (selectedVersion != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.new_releases, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${selectedVersion.label} ${selectedVersion.version}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 发布说明
          if (selectedVersion.releaseNotes != null &&
              selectedVersion.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.settingsUpgradeReleaseNotes,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  selectedVersion.releaseNotes!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],

        // 仅 Docker 环境显示回退到底包按钮
        if (check.isDocker) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Center(child: _buildResetButton(theme)),
        ],
      ],
    );
  }

  Widget _buildResetButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _isResetting ? null : _resetToBaseImage,
      icon:
          _isResetting
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.restore, size: 18),
      label: Text(
        _isResetting
            ? AppLocalizations.of(context).settingsUpgradeResetting
            : AppLocalizations.of(context).settingsUpgradeResetButton,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildUpgradeProgress(UpgradeProgress progress) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.progress / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        Text(progress.statusText),
        if (progress.message != null) ...[
          const SizedBox(height: 8),
          Text(progress.message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _buildUpgradeCompleted() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text(l10n.settingsUpgradeCompleted),
          const SizedBox(height: 8),
          Text(
            l10n.settingsUpgradeRestartSoon,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeError(UpgradeProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(Icons.error, color: colorScheme.error, size: 48),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context).settingsUpgradeFailed),
        if (progress.message != null) ...[
          const SizedBox(height: 8),
          Text(
            progress.message!,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// 上传二进制文件升级
  Future<void> _uploadAndUpgrade() async {
    final l10n = AppLocalizations.of(context);

    // 选择文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final upgradeApi = ref.read(upgradeApiProvider);
      final info = await upgradeApi.uploadBinary(file.bytes!, file.name);
      if (!mounted) return;

      // 弹出确认对话框（跨通道或同通道都确认）
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                info.channelMismatch
                    ? l10n.settingsUpgradeUploadConfirmChannel
                    : l10n.settingsUpgradeUploadConfirm,
              ),
              content: Text(
                info.channelMismatch
                    ? l10n.settingsUpgradeUploadConfirmChannelContent(
                      info.currentChannel == 'dev'
                          ? l10n.settingsUpgradeChannelDev
                          : l10n.settingsUpgradeChannelStable,
                      info.channel == 'dev'
                          ? l10n.settingsUpgradeChannelDev
                          : l10n.settingsUpgradeChannelStable,
                      info.version,
                    )
                    : l10n.settingsUpgradeUploadConfirmNormal(
                      info.version,
                      info.channel == 'dev'
                          ? l10n.settingsUpgradeChannelDev
                          : l10n.settingsUpgradeChannelStable,
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.settingsUpgradeUploadConfirm),
                ),
              ],
            ),
      );

      if (confirmed != true || !mounted) return;

      // 确认后执行升级
      await ref.read(upgradeProgressProvider.notifier).confirmUploadUpgrade();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.settingsUpgradeUploadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// 打开 GitHub Release 下载页面
  Future<void> _launchReleaseUrl() async {
    final releaseUrl =
        _checkResult?.releaseUrl ??
        'https://github.com/songloft-org/songloft/releases/latest';
    final url = Uri.parse(releaseUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  List<Widget> _buildActions(UpgradeProgress upgradeProgress) {
    final l10n = AppLocalizations.of(context);
    // 正在升级时不显示按钮
    if (upgradeProgress.isUpgrading) {
      return [];
    }

    // 升级完成
    if (upgradeProgress.isCompleted) {
      return [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsUpgradeClose),
        ),
      ];
    }

    // 升级出错
    if (upgradeProgress.isError) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsUpgradeClose),
        ),
        FilledButton(
          onPressed: () {
            ref.read(upgradeProgressProvider.notifier).reset();
            _checkUpgrade();
          },
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonRetry),
        ),
      ];
    }

    // 正在检查
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

    // 检查时发生错误（已捕获）
    if (_error != null) {
      final actions = <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsUpgradeClose),
        ),
      ];
      // Docker 环境检查失败时提供上传升级入口
      if (_checkResult?.isDocker ?? true) {
        actions.add(
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _uploadAndUpgrade,
            style: OutlinedButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            icon:
                _isUploading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.upload_file, size: 18),
            label: Text(
              _isUploading
                  ? l10n.settingsUpgradeUploading
                  : l10n.settingsUpgradeUploadButton,
            ),
          ),
        );
      }
      actions.add(
        FilledButton(
          onPressed: _checkUpgrade,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonRetry),
        ),
      );
      return actions;
    }

    // 检查结果：有更新
    if (_checkResult != null && _checkResult!.hasUpdate) {
      // 非 Docker 环境：显示"前往下载"按钮
      if (!_checkResult!.isDocker) {
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: Text(l10n.settingsUpgradeLater),
          ),
          FilledButton.icon(
            onPressed: () => _launchReleaseUrl(),
            style: FilledButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.settingsUpgradeGoDownload),
          ),
        ];
      }

      // Docker 环境：显示"立即升级"和"上传升级"按钮
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsUpgradeLater),
        ),
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _uploadAndUpgrade,
          style: OutlinedButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          icon:
              _isUploading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.upload_file, size: 18),
          label: Text(
            _isUploading
                ? l10n.settingsUpgradeUploading
                : l10n.settingsUpgradeUploadButton,
          ),
        ),
        FilledButton(
          onPressed: _isStarting ? null : _startUpgrade,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child:
              _isStarting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(l10n.settingsUpgradeUpgradeNow),
        ),
      ];
    }

    if (_checkResult != null) {
      // Docker 环境无更新时仍显示上传升级按钮（用户可能无法访问 GitHub）
      if (_checkResult!.isDocker) {
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            child: Text(l10n.settingsUpgradeClose),
          ),
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _uploadAndUpgrade,
            style: OutlinedButton.styleFrom(
              minimumSize: context.responsiveButtonMinSize,
            ),
            icon:
                _isUploading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.upload_file, size: 18),
            label: Text(
              _isUploading
                  ? l10n.settingsUpgradeUploading
                  : l10n.settingsUpgradeUploadButton,
            ),
          ),
        ];
      }
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.settingsUpgradeClose),
        ),
      ];
    }

    return [];
  }
}
