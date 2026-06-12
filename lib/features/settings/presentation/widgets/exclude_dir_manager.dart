import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../data/directory_api.dart';
import '../../data/settings_api.dart';
import '../providers/settings_provider.dart';

/// 排除目录管理组件
/// 包含两个 Tab：名称匹配排除（Autocomplete + InputChip）和路径精确排除（目录树）
class ExcludeDirManager extends ConsumerStatefulWidget {
  const ExcludeDirManager({super.key});

  @override
  ConsumerState<ExcludeDirManager> createState() => _ExcludeDirManagerState();
}

class _ExcludeDirManagerState extends ConsumerState<ExcludeDirManager> {
  // 当前选中的 Tab: 0=名称排除, 1=路径排除, 2=自动创建歌单排除
  int _selectedTab = 0;

  // 名称排除列表
  List<String> _excludeDirs = [];
  // 路径排除列表
  List<String> _excludePaths = [];
  // 自动创建歌单排除目录列表
  List<String> _autoCreateExcludeDirs = [];
  // 音乐根目录
  String _musicPath = '';

  // 自动补全候选列表
  List<String> _allDirNames = [];
  bool _isLoadingNames = false;

  // 保存状态
  bool _isSaving = false;
  bool _isLoading = true;

  // 输入控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _autoCreateExcludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _autoCreateExcludeController.dispose();
    super.dispose();
  }

  /// 加载当前配置
  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(settingsApiProvider);
      final setting = await api.getMusicPath();

      setState(() {
        _musicPath = setting.path;
        _excludeDirs = List<String>.from(setting.excludeDirs);
        _excludePaths = List<String>.from(setting.excludePaths);
        _autoCreateExcludeDirs = List<String>.from(setting.autoCreateExcludeDirs);
        _isLoading = false;
      });

      // 异步加载目录名称候选列表
      _loadDirNames();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '加载配置失败: $e');
      }
    }
  }

  /// 加载目录名称候选列表（自动补全用）
  Future<void> _loadDirNames() async {
    setState(() => _isLoadingNames = true);
    try {
      final directoryApi = ref.read(directoryApiProvider);
      final names = await directoryApi.getDirNames();
      setState(() {
        _allDirNames = names;
        _isLoadingNames = false;
      });
    } catch (e) {
      setState(() => _isLoadingNames = false);
    }
  }

  /// 添加名称排除项
  void _addExcludeDir(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _excludeDirs.contains(trimmed)) return;
    setState(() {
      _excludeDirs.add(trimmed);
    });
    _nameController.clear();
  }

  /// 移除名称排除项
  void _removeExcludeDir(String name) {
    setState(() {
      _excludeDirs.remove(name);
    });
  }

  /// 添加路径排除项
  void _addExcludePath(String path) {
    if (_excludePaths.contains(path)) return;
    setState(() {
      _excludePaths.add(path);
    });
  }

  /// 移除路径排除项
  void _removeExcludePath(String path) {
    setState(() {
      _excludePaths.remove(path);
    });
  }

  /// 添加自动创建歌单排除项
  void _addAutoCreateExcludeDir(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _autoCreateExcludeDirs.contains(trimmed)) return;
    setState(() {
      _autoCreateExcludeDirs.add(trimmed);
    });
    _autoCreateExcludeController.clear();
  }

  /// 移除自动创建歌单排除项
  void _removeAutoCreateExcludeDir(String name) {
    setState(() {
      _autoCreateExcludeDirs.remove(name);
    });
  }

  /// 保存排除配置
  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(settingsApiProvider);

      // 先读取当前完整配置，保留 path 字段
      final current = await api.getMusicPath();
      await api.updateMusicPath(
        MusicPathSetting(
          path: current.path,
          excludeDirs: _excludeDirs,
          excludePaths: _excludePaths,
          autoCreateExcludeDirs: _autoCreateExcludeDirs,
        ),
      );

      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: '排除目录配置已保存，后台正在清理被排除目录中的歌曲',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '保存失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '保存失败: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab 切换
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('名称排除'),
                icon: Icon(Icons.text_fields),
              ),
              ButtonSegment(
                value: 1,
                label: Text('路径排除'),
                icon: Icon(Icons.folder_outlined),
              ),
              ButtonSegment(
                value: 2,
                label: Text('歌单排除'),
                icon: Icon(Icons.playlist_play),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (selected) {
              setState(() => _selectedTab = selected.first);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Tab 内容
        if (_selectedTab == 0) _buildNameExcludeTab(theme, colorScheme),
        if (_selectedTab == 1) _buildPathExcludeTab(theme, colorScheme),
        if (_selectedTab == 2) _buildAutoCreateExcludeTab(theme, colorScheme),

        const SizedBox(height: AppSpacing.md),

        // 保存按钮
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '保存排除配置'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // 提示信息
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
                  '保存后将自动清理被排除目录中的已导入歌曲',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建名称排除 Tab
  Widget _buildNameExcludeTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Autocomplete 输入框
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return _allDirNames.where((name) =>
                name.toLowerCase().contains(
                    textEditingValue.text.toLowerCase()) &&
                !_excludeDirs.contains(name));
          },
          onSelected: _addExcludeDir,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // 同步外部控制器
            _nameController.addListener(() {
              if (controller.text != _nameController.text) {
                controller.text = _nameController.text;
              }
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: '输入目录名称',
                hintText: _isLoadingNames ? '正在加载候选列表...' : '输入并选择或按回车添加',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.folder_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      _addExcludeDir(controller.text);
                      controller.clear();
                    }
                  },
                  tooltip: '添加',
                ),
              ),
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _addExcludeDir(value);
                  controller.clear();
                }
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // 已排除的目录名称（InputChip）
        if (_excludeDirs.isNotEmpty) ...[
          Text(
            '已排除的目录名称:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _excludeDirs.map((name) {
              return InputChip(
                label: Text(name),
                avatar: const Icon(Icons.folder_outlined, size: 18),
                onDeleted: () => _removeExcludeDir(name),
                deleteIconColor: colorScheme.onSurfaceVariant,
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: AppSpacing.xs),
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
                  '路径中任何层级包含该名称的目录都会被排除',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建路径排除 Tab
  Widget _buildPathExcludeTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 音乐目录标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.library_music, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '音乐目录: $_musicPath',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 目录树
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SingleChildScrollView(
              child: _DirectoryTree(
                excludePaths: _excludePaths,
                onTogglePath: (path, excluded) {
                  if (excluded) {
                    _addExcludePath(path);
                  } else {
                    _removeExcludePath(path);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 已排除的路径（InputChip）
        if (_excludePaths.isNotEmpty) ...[
          Text(
            '已排除的路径:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _excludePaths.map((path) {
              // 显示相对于音乐目录的路径
              final displayPath = path.startsWith(_musicPath)
                  ? path.substring(_musicPath.length)
                  : path;
              return InputChip(
                label: Text(displayPath.isEmpty ? '/' : displayPath),
                avatar: const Icon(Icons.folder_off_outlined, size: 18),
                onDeleted: () => _removeExcludePath(path),
                deleteIconColor: colorScheme.onSurfaceVariant,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// 构建自动创建歌单排除 Tab
  Widget _buildAutoCreateExcludeTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 输入框
        TextFormField(
          controller: _autoCreateExcludeController,
          decoration: InputDecoration(
            labelText: '输入目录名称',
            hintText: '输入并选择或按回车添加',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.folder_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (_autoCreateExcludeController.text.trim().isNotEmpty) {
                  _addAutoCreateExcludeDir(_autoCreateExcludeController.text);
                }
              },
              tooltip: '添加',
            ),
          ),
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _addAutoCreateExcludeDir(value);
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // 已排除的目录名称（InputChip）
        if (_autoCreateExcludeDirs.isNotEmpty) ...[
          Text(
            '自动创建歌单时不纳入的目录:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _autoCreateExcludeDirs.map((name) {
              return InputChip(
                label: Text(name),
                avatar: const Icon(Icons.folder_outlined, size: 18),
                onDeleted: () => _removeAutoCreateExcludeDir(name),
                deleteIconColor: colorScheme.onSurfaceVariant,
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: AppSpacing.xs),
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
                  '路径中任何层级包含该名称的目录都不会被自动创建歌单',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 目录树组件（懒加载）
class _DirectoryTree extends ConsumerStatefulWidget {
  final List<String> excludePaths;
  final void Function(String path, bool excluded) onTogglePath;

  const _DirectoryTree({
    required this.excludePaths,
    required this.onTogglePath,
  });

  @override
  ConsumerState<_DirectoryTree> createState() => _DirectoryTreeState();
}

class _DirectoryTreeState extends ConsumerState<_DirectoryTree> {
  List<DirEntry>? _rootDirs;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRootDirs();
  }

  Future<void> _loadRootDirs() async {
    try {
      final directoryApi = ref.read(directoryApiProvider);
      final result = await directoryApi.getDirectories();
      setState(() {
        _rootDirs = result.directories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('加载目录失败: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    if (_rootDirs == null || _rootDirs!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('目录为空',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    return Column(
      children: _rootDirs!.map((dir) {
        return _DirectoryTreeNode(
          entry: dir,
          excludePaths: widget.excludePaths,
          onTogglePath: widget.onTogglePath,
          depth: 0,
        );
      }).toList(),
    );
  }
}

/// 目录树节点组件
class _DirectoryTreeNode extends ConsumerStatefulWidget {
  final DirEntry entry;
  final List<String> excludePaths;
  final void Function(String path, bool excluded) onTogglePath;
  final int depth;

  const _DirectoryTreeNode({
    required this.entry,
    required this.excludePaths,
    required this.onTogglePath,
    required this.depth,
  });

  @override
  ConsumerState<_DirectoryTreeNode> createState() =>
      _DirectoryTreeNodeState();
}

class _DirectoryTreeNodeState extends ConsumerState<_DirectoryTreeNode> {
  bool _isExpanded = false;
  List<DirEntry>? _children;
  bool _isLoadingChildren = false;

  bool get _isExcluded => widget.excludePaths.contains(widget.entry.path);

  Future<void> _loadChildren() async {
    if (_children != null) return;
    setState(() => _isLoadingChildren = true);
    try {
      final directoryApi = ref.read(directoryApiProvider);
      final result =
          await directoryApi.getDirectories(path: widget.entry.path);
      setState(() {
        _children = result.directories;
        _isLoadingChildren = false;
      });
    } catch (e) {
      setState(() {
        _children = [];
        _isLoadingChildren = false;
      });
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && _children == null) {
      _loadChildren();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: widget.entry.hasChildren ? _toggleExpand : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + widget.depth * 24.0,
              right: 8.0,
              top: 4.0,
              bottom: 4.0,
            ),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isExcluded,
                    onChanged: (value) {
                      widget.onTogglePath(
                          widget.entry.path, value ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 文件夹图标
                Icon(
                  _isExcluded
                      ? Icons.folder_off_outlined
                      : (_isExpanded
                          ? Icons.folder_open
                          : Icons.folder_outlined),
                  size: 20,
                  color: _isExcluded
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // 目录名称
                Expanded(
                  child: Text(
                    widget.entry.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _isExcluded
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      decoration:
                          _isExcluded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                // 展开/折叠箭头
                if (widget.entry.hasChildren)
                  Icon(
                    _isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                // 加载指示器
                if (_isLoadingChildren)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        // 子目录
        if (_isExpanded && _children != null)
          ..._children!.map((child) {
            return _DirectoryTreeNode(
              entry: child,
              excludePaths: widget.excludePaths,
              onTogglePath: widget.onTogglePath,
              depth: widget.depth + 1,
            );
          }),
      ],
    );
  }
}
