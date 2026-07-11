import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../features/settings/data/directory_api.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';

/// 目录树选择语义：
/// - [include]：勾选表示"纳入"（如目录级定向扫描，选中的目录才被扫描）
/// - [exclude]：勾选表示"排除"（如扫描排除目录，选中的目录被跳过，显示删除线）
enum DirectoryTreeSelectorMode { include, exclude }

/// 可复用的懒加载勾选目录树。
///
/// 消费 [DirectoryApi]（GET /scan/directories）按需加载子目录，每个节点带 [Checkbox]，
/// 选中态由外部通过 [selectedPaths] 维护，勾选/取消通过 [onTogglePath] 回传。
/// [mode] 仅影响图标与文案语义（纳入 vs 排除），数据流与懒加载逻辑一致。
///
/// 原为 exclude_dir_manager.dart 内的私有实现，提取为公开组件供扫描定向选择
/// 与排除目录设置共用（Issue songloft-org/songloft#262）。
class DirectoryTreeSelector extends ConsumerStatefulWidget {
  final List<String> selectedPaths;
  final void Function(String path, bool selected) onTogglePath;
  final DirectoryTreeSelectorMode mode;

  const DirectoryTreeSelector({
    super.key,
    required this.selectedPaths,
    required this.onTogglePath,
    this.mode = DirectoryTreeSelectorMode.include,
  });

  @override
  ConsumerState<DirectoryTreeSelector> createState() =>
      _DirectoryTreeSelectorState();
}

class _DirectoryTreeSelectorState extends ConsumerState<DirectoryTreeSelector> {
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
        child: Text(AppLocalizations.of(context).loadDirFailed('$_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    if (_rootDirs == null || _rootDirs!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(AppLocalizations.of(context).dirEmpty,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    return Column(
      children: _rootDirs!.map((dir) {
        return _DirectoryTreeNode(
          entry: dir,
          selectedPaths: widget.selectedPaths,
          onTogglePath: widget.onTogglePath,
          mode: widget.mode,
          depth: 0,
        );
      }).toList(),
    );
  }
}

/// 目录树节点组件
class _DirectoryTreeNode extends ConsumerStatefulWidget {
  final DirEntry entry;
  final List<String> selectedPaths;
  final void Function(String path, bool selected) onTogglePath;
  final DirectoryTreeSelectorMode mode;
  final int depth;

  const _DirectoryTreeNode({
    required this.entry,
    required this.selectedPaths,
    required this.onTogglePath,
    required this.mode,
    required this.depth,
  });

  @override
  ConsumerState<_DirectoryTreeNode> createState() => _DirectoryTreeNodeState();
}

class _DirectoryTreeNodeState extends ConsumerState<_DirectoryTreeNode> {
  bool _isExpanded = false;
  List<DirEntry>? _children;
  bool _isLoadingChildren = false;

  bool get _isSelected => widget.selectedPaths.contains(widget.entry.path);
  bool get _isExcludeMode =>
      widget.mode == DirectoryTreeSelectorMode.exclude;

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

    // 排除语义下选中显示"灰化 + 删除线 + folder_off"，纳入语义下选中显示"高亮"。
    final dimmed = _isExcludeMode && _isSelected;
    final IconData folderIcon = dimmed
        ? Icons.folder_off_outlined
        : (_isExpanded ? Icons.folder_open : Icons.folder_outlined);

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
                    value: _isSelected,
                    onChanged: (value) {
                      widget.onTogglePath(widget.entry.path, value ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // 文件夹图标
                Icon(
                  folderIcon,
                  size: 20,
                  color: dimmed ? colorScheme.onSurfaceVariant : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // 目录名称
                Expanded(
                  child: Text(
                    widget.entry.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: dimmed
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      decoration:
                          dimmed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                // 展开/折叠箭头
                if (widget.entry.hasChildren)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                // 加载指示器
                if (_isLoadingChildren)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
              selectedPaths: widget.selectedPaths,
              onTogglePath: widget.onTogglePath,
              mode: widget.mode,
              depth: widget.depth + 1,
            );
          }),
      ],
    );
  }
}
