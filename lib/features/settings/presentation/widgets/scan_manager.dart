import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
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
      setState(() => _error = '扫描失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelScan() async {
    try {
      await ref.read(scanProgressProvider.notifier).cancelScan();
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '取消失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '取消失败: $e');
      }
    }
  }

  void _reset() {
    ref.read(scanProgressProvider.notifier).reset();
    setState(() => _error = null);
  }

  String get _modeDescription {
    return _scanMode == 'skip' ? '仅导入新发现的音乐文件' : '重新扫描并覆盖所有音乐信息';
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(scanProgressProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  tooltip: '关闭提示',
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
                title: const Text('排除目录设置'),
                subtitle: Text(
                  '配置扫描时需要忽略的目录',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 带图标的 SegmentedButton（全宽）
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'skip',
                label: Text('跳过已存在'),
                icon: Icon(Icons.skip_next_outlined),
              ),
              ButtonSegment(
                value: 'reimport',
                label: Text('重新导入'),
                icon: Icon(Icons.refresh_outlined),
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
                  _modeDescription,
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
                  ? '正在启动...'
                  : (_selectedPaths.isEmpty
                      ? '扫描本地音乐'
                      : '扫描选中的 ${_selectedPaths.length} 个目录'),
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
            title: const Text('指定目录（可选）'),
            subtitle: Text(
              _selectedPaths.isEmpty
                  ? '仅扫描选中的目录，留空则扫描整个音乐库'
                  : '已选 ${_selectedPaths.length} 个目录',
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
                            '将扫描的目录:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedPaths.clear()),
                          child: const Text('清空'),
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
          Text('正在按目录自动创建歌单...', style: Theme.of(context).textTheme.bodySmall)
        else if (isSplittingCue) ...[
          Text(
            '正在切分整轨(CUE)${progress.cueSplitSources > 0 ? ': 已处理 ${progress.cueSplitSources} 个来源' : '...'}',
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
            '正在发现文件${progress.discoveredFiles > 0 ? ': 已发现 ${progress.discoveredFiles} 个' : '...'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...[
          if (progress.currentFile != null)
            Text(
              '正在扫描: ${progress.currentFile}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            '已处理: ${progress.scannedFiles}/${progress.totalFiles}, 导入: ${progress.importedFiles}, 跳过: ${progress.skippedFiles}, 失败: ${progress.failedFiles}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          // CUE 切分阶段后端支持取消，仅自动创建歌单阶段禁用
          onPressed: isCreatingPlaylists ? null : _cancelScan,
          icon: const Icon(Icons.cancel),
          label: const Text('取消扫描'),
        ),
      ],
    );
  }

  /// 「扫描后自动创建歌单」总开关
  Widget _buildAutoCreatePlaylistsTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
        title: const Text('扫描后自动创建歌单'),
        subtitle: Text(
          asyncValue.when(
            data: (_) => '按目录结构自动生成歌单',
            loading: () => '加载中...',
            error: (_, _) => '读取配置失败',
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
                        message: '保存失败: $e',
                      );
                    }
                  }
                },
      ),
    );
  }

  static const _playlistModes = <String, (String, String)>{
    'directory': ('按文件夹', '每个文件夹生成独立歌单'),
    'top_level': ('按顶层文件夹', '子文件夹的歌曲合并到一级文件夹歌单'),
    'bubble_up': ('包含子目录', '歌曲同时出现在所有上级文件夹歌单'),
  };

  /// 「歌单创建方式」下拉选择
  Widget _buildPlaylistModeTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final asyncValue = ref.watch(scanPlaylistModeProvider);
    final autoCreateAsync = ref.watch(autoCreatePlaylistsProvider);
    final autoCreateEnabled = autoCreateAsync.value ?? true;
    final currentMode = asyncValue.value ?? 'directory';
    final disabled = !autoCreateEnabled || asyncValue.isLoading;
    const disabledAlpha = 0.4;

    final (_, currentDesc) =
        _playlistModes[currentMode] ?? _playlistModes['directory']!;

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
          '歌单创建方式',
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
                loading: () => '加载中...',
                error: (_, _) => '读取配置失败',
              )
              : '已关闭自动创建歌单，此项不生效',
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
                          message: '保存失败: $e',
                        );
                      }
                    }
                  },
          selectedItemBuilder:
              (_) =>
                  _playlistModes.entries.map((e) {
                    final (label, _) = e.value;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    );
                  }).toList(),
          items:
              _playlistModes.entries.map((e) {
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
        title: const Text('使用文件名作为标题'),
        subtitle: Text(
          isFilename ? '歌曲标题使用文件名（不含扩展名），适合文件名已编号的情况' : '歌曲标题优先使用音频标签信息',
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
                        message: '已保存，需以「重新导入」模式扫描后生效',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ResponsiveSnackBar.showError(
                        context,
                        message: '保存失败: $e',
                      );
                    }
                  }
                },
      ),
    );
  }

  static const _intervalOptions = <int, String>{
    600: '10 分钟',
    1800: '30 分钟',
    3600: '1 小时',
    10800: '3 小时',
    21600: '6 小时',
    43200: '12 小时',
    86400: '24 小时',
  };

  static String _intervalLabel(int seconds) {
    return _intervalOptions[seconds] ?? '$seconds 秒';
  }

  Widget _buildAutoScanTile() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            title: const Text('自动扫描'),
            subtitle: Text(
              setting.enabled
                  ? '每 ${_intervalLabel(setting.intervalSeconds)} 自动扫描一次'
                  : '关闭',
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
                            message: '保存失败: $e',
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
                    '扫描间隔',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue:
                          _intervalOptions.containsKey(setting.intervalSeconds)
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
                          _intervalOptions.entries
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
                                      message: '保存失败: $e',
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
                    Text('扫描完成，本地歌曲共 ${progress.localSongCount} 首'),
                    Text(
                      '本次导入 ${progress.importedFiles} 首，跳过 ${progress.skippedFiles} 首，失败 ${progress.failedFiles} 个',
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
            label: const Text('重新扫描'),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledState(ScanProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  '扫描已取消 (已处理 ${progress.scannedFiles} 个文件)',
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
            label: const Text('重新扫描'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ScanProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;

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
              const Expanded(child: Text('扫描出错')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
      ],
    );
  }
}
