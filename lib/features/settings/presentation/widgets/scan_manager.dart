import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/directory_tree_selector.dart';
import '../../data/scan_api.dart';
import '../../data/settings_api.dart';
import '../providers/settings_provider.dart';
import 'exclude_dir_manager.dart';

/// 扫描管理组件
class ScanManager extends ConsumerStatefulWidget {
  const ScanManager({super.key});

  @override
  ConsumerState<ScanManager> createState() => _ScanManagerState();
}

class _ScanManagerState extends ConsumerState<ScanManager> {
  bool _isLoading = false;
  String? _error;
  String _scanMode = 'skip'; // 'skip' 或 'reimport'
  bool _showExcludeDirs = false; // 是否展开排除目录设置
  bool _showTargetDirs = false; // 是否展开"指定目录"定向扫描
  // 定向扫描选中的目录（为空=全库扫描）。Issue songloft-org/songloft#262
  final List<String> _selectedPaths = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanProgressProvider.notifier).refreshProgress();
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(scanProgressProvider.notifier).startScan(
            reimport: _scanMode == 'reimport',
            paths: _selectedPaths.isEmpty ? null : List.of(_selectedPaths),
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = AppLocalizations.of(context).settingsScanScanFailed('$e'),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelScan() async {
    try {
      await ref.read(scanProgressProvider.notifier).cancelScan();
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).settingsScanCancelFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).settingsScanCancelFailed('$e'),
        );
      }
    }
  }

  void _reset() {
    ref.read(scanProgressProvider.notifier).reset();
    setState(() => _error = null);
  }

  String _modeDescription(AppLocalizations l10n) {
    return _scanMode == 'skip'
        ? l10n.settingsScanModeSkipDesc
        : l10n.settingsScanModeReimportDesc;
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(scanProgressProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 错误信息
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.settingsScanDismiss,
                  onPressed: () => setState(() => _error = null),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildAutoCreatePlaylistsTile(),
        const SizedBox(height: AppSpacing.md),

        // 「歌单创建方式」选择
        _buildPlaylistModeTile(),
        const SizedBox(height: AppSpacing.md),

        // 「标题来源」切换
        _buildTitleSourceTile(),
        const SizedBox(height: AppSpacing.md),

        // 自动扫描设置
        _buildAutoScanTile(),
        const SizedBox(height: AppSpacing.md),

        // 排除目录设置（可展开/折叠）
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.folder_off_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.settingsScanExcludeDirTitle),
                subtitle: Text(
                  l10n.settingsScanExcludeDirSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  _showExcludeDirs ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: () {
                  setState(() => _showExcludeDirs = !_showExcludeDirs);
                },
              ),
              if (_showExcludeDirs)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: ExcludeDirManager(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 根据状态显示不同内容
        if (progress.isIdle) _buildIdleState(),
        if (progress.isScanning) _buildScanningState(progress),
        if (progress.isCompleted) _buildCompletedState(progress),
        if (progress.isCancelled) _buildCancelledState(progress),
        if (progress.isError) _buildErrorState(progress),
      ],
    );
  }

  /// 构建空闲状态 UI（扫描模式选择 + 扫描按钮）
  Widget _buildIdleState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 带图标的 SegmentedButton（全宽）
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'skip',
                label: Text(l10n.settingsScanModeSkip),
                icon: const Icon(Icons.skip_next_outlined),
              ),
              ButtonSegment(
                value: 'reimport',
                label: Text(l10n.settingsScanModeReimport),
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
            selected: {_scanMode},
            onSelectionChanged: (selected) {
              setState(() => _scanMode = selected.first);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 当前模式描述文字
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _modeDescription(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 指定目录（可选）——目录级定向扫描。留空即全库扫描。
        _buildTargetDirsSection(theme, colorScheme),
        const SizedBox(height: AppSpacing.md),

        // 全宽扫描按钮
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _startScan,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.search),
            label: Text(
              _isLoading
                  ? l10n.settingsScanStarting
                  : (_selectedPaths.isEmpty
                      ? l10n.settingsScanScanLocal
                      : l10n.settingsScanScanSelectedDirs(_selectedPaths.length)),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建"指定目录"定向扫描区（可展开/折叠）。
  /// 勾选目录后仅扫描这些目录（含子目录），且过期记录清理仅收敛到所选目录之内；
  /// 不勾选时保持全库扫描行为。
  Widget _buildTargetDirsSection(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.rule_folder_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            title: Text(l10n.settingsScanTargetDirsTitle),
            subtitle: Text(
              _selectedPaths.isEmpty
                  ? l10n.settingsScanTargetDirsSubtitle
                  : l10n.settingsScanTargetDirsSelected(_selectedPaths.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              _showTargetDirs ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() => _showTargetDirs = !_showTargetDirs);
            },
          ),
          if (_showTargetDirs)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 目录树（勾选=纳入扫描）
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SingleChildScrollView(
                        child: DirectoryTreeSelector(
                          selectedPaths: _selectedPaths,
                          onTogglePath: (path, selected) {
                            setState(() {
                              if (selected) {
                                if (!_selectedPaths.contains(path)) {
                                  _selectedPaths.add(path);
                                }
                              } else {
                                _selectedPaths.remove(path);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  // 已选目录（InputChip）+ 清空
                  if (_selectedPaths.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.settingsScanDirsToScan,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedPaths.clear()),
                          child: Text(l10n.settingsScanClear),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _selectedPaths.map((path) {
                        return InputChip(
                          label: Text(_dirDisplayName(path)),
                          avatar: const Icon(Icons.folder_outlined, size: 18),
                          onDeleted: () =>
                              setState(() => _selectedPaths.remove(path)),
                          deleteIconColor: colorScheme.onSurfaceVariant,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 取目录路径的末段作为 Chip 展示名（兼容 / 与 \ 分隔）。
  String _dirDisplayName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final idx = trimmed.lastIndexOf('/');
    final name = idx >= 0 ? trimmed.substring(idx + 1) : trimmed;
    return name.isEmpty ? path : name;
  }

  Widget _buildScanningState(ScanProgress progress) {
    final l10n = AppLocalizations.of(context);
    final isCreatingPlaylists = progress.isCreatingPlaylists;
    final isSplittingCue = progress.isSplittingCue;
    final isDiscovering = progress.status == 'scanning';
    // 发现文件、CUE 切分、创建歌单阶段进度不可量化，用不确定进度条
    final indeterminate =
        isCreatingPlaylists || isSplittingCue || isDiscovering;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: indeterminate ? null : progress.progress / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        if (isCreatingPlaylists)
          Text(
            l10n.settingsScanCreatingPlaylists,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else if (isSplittingCue) ...[
          Text(
            progress.cueSplitSources > 0
                ? l10n.settingsScanSplittingCueProgress(progress.cueSplitSources)
                : l10n.settingsScanSplittingCue,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (progress.currentFile != null && progress.currentFile!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              progress.currentFile!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ] else if (isDiscovering) ...[
          Text(
            progress.discoveredFiles > 0
                ? l10n.settingsScanDiscoveringProgress(progress.discoveredFiles)
                : l10n.settingsScanDiscovering,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...[
          if (progress.currentFile != null)
            Text(
              l10n.settingsScanScanningFile('${progress.currentFile}'),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsScanProgressStats(
              progress.scannedFiles,
              progress.totalFiles,
              progress.importedFiles,
              progress.skippedFiles,
              progress.failedFiles,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          // CUE 切分阶段后端支持取消，仅自动创建歌单阶段禁用
          onPressed: isCreatingPlaylists ? null : _cancelScan,
          icon: const Icon(Icons.cancel),
          label: Text(l10n.settingsScanCancelScan),
        ),
      ],
    );
  }

  /// 「扫描后自动创建歌单」总开关
  Widget _buildAutoCreatePlaylistsTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final asyncValue = ref.watch(autoCreatePlaylistsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        secondary: Icon(
          Icons.playlist_add_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.settingsScanAutoCreatePlaylists),
        subtitle: Text(
          asyncValue.when(
            data: (_) => l10n.settingsScanAutoCreatePlaylistsDesc,
            loading: () => l10n.settingsScanLoadingConfig,
            error: (_, _) => l10n.settingsScanReadConfigFailed,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        value: asyncValue.value ?? true,
        onChanged:
            asyncValue.isLoading
                ? null
                : (value) async {
                  try {
                    await ref
                        .read(autoCreatePlaylistsProvider.notifier)
                        .setValue(value);
                  } catch (e) {
                    if (mounted) {
                      ResponsiveSnackBar.showError(
                        context,
                        message: l10n.settingsScanSaveFailed('$e'),
                      );
                    }
                  }
                },
      ),
    );
  }

  Map<String, (String, String)> _playlistModes(AppLocalizations l10n) => {
    'directory': (
      l10n.settingsScanPlaylistModeDirectory,
      l10n.settingsScanPlaylistModeDirectoryDesc,
    ),
    'top_level': (
      l10n.settingsScanPlaylistModeTopLevel,
      l10n.settingsScanPlaylistModeTopLevelDesc,
    ),
    'bubble_up': (
      l10n.settingsScanPlaylistModeBubbleUp,
      l10n.settingsScanPlaylistModeBubbleUpDesc,
    ),
  };

  /// 「歌单创建方式」下拉选择
  Widget _buildPlaylistModeTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final playlistModes = _playlistModes(l10n);
    final asyncValue = ref.watch(scanPlaylistModeProvider);
    final autoCreateAsync = ref.watch(autoCreatePlaylistsProvider);
    final autoCreateEnabled = autoCreateAsync.value ?? true;
    final currentMode = asyncValue.value ?? 'directory';
    final disabled = !autoCreateEnabled || asyncValue.isLoading;
    const disabledAlpha = 0.4;

    final (_, currentDesc) =
        playlistModes[currentMode] ?? playlistModes['directory']!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          Icons.account_tree_outlined,
          color:
              autoCreateEnabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: disabledAlpha),
        ),
        title: Text(
          l10n.settingsScanPlaylistModeTitle,
          style: TextStyle(
            color:
                autoCreateEnabled
                    ? null
                    : colorScheme.onSurface.withValues(alpha: disabledAlpha),
          ),
        ),
        subtitle: Text(
          autoCreateEnabled
              ? asyncValue.when(
                data: (_) => currentDesc,
                loading: () => l10n.settingsScanLoadingConfig,
                error: (_, _) => l10n.settingsScanReadConfigFailed,
              )
              : l10n.settingsScanPlaylistModeDisabled,
          style: theme.textTheme.bodySmall?.copyWith(
            color:
                autoCreateEnabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: disabledAlpha),
          ),
        ),
        trailing: DropdownButton<String>(
          value: currentMode,
          underline: const SizedBox.shrink(),
          onChanged:
              disabled
                  ? null
                  : (value) async {
                    if (value == null) return;
                    try {
                      await ref
                          .read(scanPlaylistModeProvider.notifier)
                          .setValue(value);
                    } catch (e) {
                      if (mounted) {
                        ResponsiveSnackBar.showError(
                          context,
                          message: l10n.settingsScanSaveFailed('$e'),
                        );
                      }
                    }
                  },
          selectedItemBuilder:
              (_) =>
                  playlistModes.entries.map((e) {
                    final (label, _) = e.value;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    );
                  }).toList(),
          items:
              playlistModes.entries.map((e) {
                final (label, desc) = e.value;
                return DropdownMenuItem(
                  value: e.key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodyMedium),
                      Text(
                        desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// 「标题来源」切换（标签 / 文件名）
  Widget _buildTitleSourceTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final asyncValue = ref.watch(scanTitleSourceProvider);

    final isFilename = (asyncValue.value ?? 'tag') == 'filename';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        secondary: Icon(
          Icons.title_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(l10n.settingsScanTitleSource),
        subtitle: Text(
          isFilename
              ? l10n.settingsScanTitleSourceFilenameDesc
              : l10n.settingsScanTitleSourceTagDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        value: isFilename,
        onChanged:
            asyncValue.isLoading
                ? null
                : (value) async {
                  try {
                    await ref
                        .read(scanTitleSourceProvider.notifier)
                        .setValue(value ? 'filename' : 'tag');
                    if (mounted) {
                      ResponsiveSnackBar.show(
                        context,
                        message: l10n.settingsScanTitleSourceSaved,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ResponsiveSnackBar.showError(
                        context,
                        message: l10n.settingsScanSaveFailed('$e'),
                      );
                    }
                  }
                },
      ),
    );
  }

  static Map<int, String> _intervalOptions(AppLocalizations l10n) => {
    600: l10n.settingsScanInterval10Min,
    1800: l10n.settingsScanInterval30Min,
    3600: l10n.settingsScanInterval1Hour,
    10800: l10n.settingsScanInterval3Hour,
    21600: l10n.settingsScanInterval6Hour,
    43200: l10n.settingsScanInterval12Hour,
    86400: l10n.settingsScanInterval24Hour,
  };

  static String _intervalLabel(AppLocalizations l10n, int seconds) {
    return _intervalOptions(l10n)[seconds] ??
        l10n.settingsScanIntervalSeconds(seconds);
  }

  Widget _buildAutoScanTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final asyncValue = ref.watch(autoScanProvider);
    final setting =
        asyncValue.value ??
        AutoScanSetting(enabled: false, intervalSeconds: 3600);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.autorenew,
              color: colorScheme.onSurfaceVariant,
            ),
            title: Text(l10n.settingsScanAutoScan),
            subtitle: Text(
              setting.enabled
                  ? l10n.settingsScanAutoScanInterval(
                    _intervalLabel(l10n, setting.intervalSeconds),
                  )
                  : l10n.settingsScanAutoScanOff,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: setting.enabled,
            onChanged:
                asyncValue.isLoading
                    ? null
                    : (value) async {
                      try {
                        await ref
                            .read(autoScanProvider.notifier)
                            .setValue(setting.copyWith(enabled: value));
                      } catch (e) {
                        if (mounted) {
                          ResponsiveSnackBar.showError(
                            context,
                            message: l10n.settingsScanSaveFailed('$e'),
                          );
                        }
                      }
                    },
          ),
          if (setting.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 40,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.settingsScanScanInterval,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue:
                          _intervalOptions(l10n).containsKey(
                                setting.intervalSeconds,
                              )
                              ? setting.intervalSeconds
                              : 3600,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items:
                          _intervalOptions(l10n).entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                      onChanged:
                          asyncValue.isLoading
                              ? null
                              : (value) async {
                                if (value == null) return;
                                try {
                                  await ref
                                      .read(autoScanProvider.notifier)
                                      .setValue(
                                        setting.copyWith(
                                          intervalSeconds: value,
                                        ),
                                      );
                                } catch (e) {
                                  if (mounted) {
                                    ResponsiveSnackBar.showError(
                                      context,
                                      message: l10n.settingsScanSaveFailed('$e'),
                                    );
                                  }
                                }
                              },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedState(ScanProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsScanCompletedSummary(progress.localSongCount),
                    ),
                    Text(
                      l10n.settingsScanCompletedStats(
                        progress.importedFiles,
                        progress.skippedFiles,
                        progress.failedFiles,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.settingsScanRescan),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledState(ScanProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.settingsScanCancelledSummary(progress.scannedFiles),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.settingsScanRescan),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ScanProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.settingsScanErrorTitle)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ),
      ],
    );
  }
}
