import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/directory_api.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';

/// 单选目录选择器（底部弹窗）。
///
/// 展示从 `/api/v1/scan/directories` 拿到的音乐目录树，懒加载子目录。
/// 顶部一个「全部」选项用于清除筛选。
/// 用法：
/// ```dart
/// final path = await DirectoryPickerSheet.show(context, currentPath: ...);
/// // path == null 表示用户取消（保持现状）；
/// // path == DirectoryPickerSheet.allValue 表示选了「全部」（应清空筛选）；
/// // 其它字符串为具体目录路径。
/// ```
class DirectoryPickerSheet extends ConsumerStatefulWidget {
  /// 「全部（清除筛选）」的特殊返回值。空字符串区别于 null（取消）。
  static const String allValue = '';

  /// 当前选中的路径，用于高亮。空串表示「全部」。
  final String currentPath;

  const DirectoryPickerSheet({super.key, required this.currentPath});

  static Future<String?> show(
    BuildContext context, {
    String currentPath = allValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DirectoryPickerSheet(currentPath: currentPath),
    );
  }

  @override
  ConsumerState<DirectoryPickerSheet> createState() =>
      _DirectoryPickerSheetState();
}

class _DirectoryPickerSheetState extends ConsumerState<DirectoryPickerSheet> {
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
      final api = ref.read(directoryApiProvider);
      final result = await api.getDirectories();
      if (!mounted) return;
      setState(() {
        _rootDirs = result.directories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _select(String path) {
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '选择文件夹',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '加载目录失败：$_error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      );
    }
    final dirs = _rootDirs ?? const <DirEntry>[];
    return ListView(
      children: [
        _AllRow(
          selected: widget.currentPath == DirectoryPickerSheet.allValue,
          onTap: () => _select(DirectoryPickerSheet.allValue),
        ),
        const Divider(height: 1),
        if (dirs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '音乐目录为空',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...dirs.map(
            (d) => _DirectoryNode(
              entry: d,
              currentPath: widget.currentPath,
              onSelect: _select,
              depth: 0,
            ),
          ),
      ],
    );
  }
}

class _AllRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AllRow({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.all_inbox,
              size: 20,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '全部歌曲',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? colorScheme.primary : null,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _DirectoryNode extends ConsumerStatefulWidget {
  final DirEntry entry;
  final String currentPath;
  final ValueChanged<String> onSelect;
  final int depth;

  const _DirectoryNode({
    required this.entry,
    required this.currentPath,
    required this.onSelect,
    required this.depth,
  });

  @override
  ConsumerState<_DirectoryNode> createState() => _DirectoryNodeState();
}

class _DirectoryNodeState extends ConsumerState<_DirectoryNode> {
  bool _isExpanded = false;
  List<DirEntry>? _children;
  bool _isLoadingChildren = false;

  bool get _isSelected => widget.entry.path == widget.currentPath;

  Future<void> _loadChildren() async {
    if (_children != null) return;
    setState(() => _isLoadingChildren = true);
    try {
      final api = ref.read(directoryApiProvider);
      final result = await api.getDirectories(path: widget.entry.path);
      if (!mounted) return;
      setState(() {
        _children = result.directories;
        _isLoadingChildren = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _children = [];
        _isLoadingChildren = false;
      });
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && _children == null) {
      _loadChildren();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onSelect(widget.entry.path),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + widget.depth * 20.0,
              right: 8.0,
              top: 10.0,
              bottom: 10.0,
            ),
            child: Row(
              children: [
                // 展开/折叠按钮（仅当有子目录）
                SizedBox(
                  width: 28,
                  child: widget.entry.hasChildren
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 20,
                          ),
                          onPressed: _toggleExpand,
                        )
                      : const SizedBox.shrink(),
                ),
                Icon(
                  _isExpanded ? Icons.folder_open : Icons.folder_outlined,
                  size: 20,
                  color: _isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.entry.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          _isSelected ? FontWeight.bold : FontWeight.normal,
                      color: _isSelected ? colorScheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoadingChildren)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_isSelected)
                  Icon(Icons.check, size: 18, color: colorScheme.primary),
              ],
            ),
          ),
        ),
        if (_isExpanded && _children != null)
          ..._children!.map(
            (child) => _DirectoryNode(
              entry: child,
              currentPath: widget.currentPath,
              onSelect: widget.onSelect,
              depth: widget.depth + 1,
            ),
          ),
      ],
    );
  }
}
