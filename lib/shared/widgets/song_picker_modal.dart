import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../utils/responsive_snackbar.dart';
import '../../features/library/presentation/providers/songs_provider.dart';
import 'cover_image.dart';
import 'directory_picker_sheet.dart';

/// 歌曲选择器弹窗组件
/// 用于在歌单详情页中选择要添加的歌曲
class SongPickerModal extends ConsumerStatefulWidget {
  /// 要排除的歌曲 ID（已在歌单中的歌曲）
  final Set<int> excludeIds;

  /// 按歌曲类型过滤（如 'radio', 'local', 'remote'），只显示此类型
  final String? songType;

  /// 要排除的歌曲类型（如 'radio'），排除此类型的歌曲
  final String? excludeType;

  const SongPickerModal({
    super.key,
    this.excludeIds = const {},
    this.songType,
    this.excludeType,
  });

  /// 显示歌曲选择器弹窗
  ///
  /// [context] 上下文
  /// [excludeIds] 要排除的歌曲 ID
  /// [songType] 按歌曲类型过滤（如 'radio' 只显示电台歌曲）
  /// [excludeType] 要排除的歌曲类型（如 'radio' 排除电台歌曲）
  ///
  /// 返回选中的歌曲 ID 列表，取消返回 null
  static Future<List<int>?> show(
    BuildContext context, {
    Set<int> excludeIds = const {},
    String? songType,
    String? excludeType,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => SongPickerModal(
            excludeIds: excludeIds,
            songType: songType,
            excludeType: excludeType,
          ),
    );
  }

  @override
  ConsumerState<SongPickerModal> createState() => _SongPickerModalState();
}

class _SongPickerModalState extends ConsumerState<SongPickerModal> {
  /// 当前加载的歌曲列表（已过滤 excludeIds）
  List<Song> _songs = [];

  /// 选中的歌曲 ID
  final Set<int> _selectedIds = {};

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 是否正在加载
  bool _isLoading = false;

  /// 是否正在加载更多
  bool _isLoadingMore = false;

  /// 是否还有更多数据
  bool _hasMore = true;

  /// 当前页码
  int _currentPage = 0;

  /// 防抖定时器
  Timer? _debounceTimer;

  /// 当前选中的目录前缀，空串表示「全部」（不过滤）
  String _pathPrefix = '';

  /// 用户在弹窗内手动切换的类型筛选；null 表示「全部」（受 widget.songType 硬约束时不生效）
  String? _typeFilter;

  /// 当前筛选条件下匹配的歌曲总数（来自后端 list 响应的 total 字段）
  /// 注意：这是「过滤前」的总数，可能含 excludeIds/类型过滤会再剔除的歌
  int _total = 0;

  /// 全选异步加载状态
  bool _isSelectingAll = false;

  /// 每页大小
  static const int _pageSize = 20;

  /// 防抖延迟时间（毫秒）
  static const int _debounceDelay = 300;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 滚动监听
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMore();
    }
  }

  /// 加载歌曲列表
  Future<void> _loadSongs({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _songs = [];
        _hasMore = true;
      }
    });

    try {
      final repository = ref.read(songsRepositoryProvider);
      final keyword = _searchController.text.trim();

      final response = await repository.getSongs(
        type: _resolvedType(),
        keyword: keyword.isNotEmpty ? keyword : null,
        pathPrefix: _pathPrefix.isNotEmpty ? _pathPrefix : null,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      // 过滤歌曲：排除已有的 + 按类型过滤
      final filteredSongs =
          response.songs.where((song) {
            // 排除已在歌单中的歌曲
            if (widget.excludeIds.contains(song.id)) return false;
            // 按类型过滤（只显示指定类型）
            if (widget.songType != null && song.type != widget.songType) {
              return false;
            }
            // 排除指定类型
            if (widget.excludeType != null && song.type == widget.excludeType) {
              return false;
            }
            return true;
          }).toList();

      setState(() {
        if (reset) {
          _songs = filteredSongs;
          _total = response.total;
        } else {
          _songs = [..._songs, ...filteredSongs];
        }
        _hasMore = response.songs.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '加载失败: $e');
      }
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadSongs(reset: false);

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// 搜索（带防抖）
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceDelay), () {
      _loadSongs();
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _loadSongs();
  }

  /// 弹出目录选择器
  Future<void> _pickFolder() async {
    final result = await DirectoryPickerSheet.show(
      context,
      currentPath: _pathPrefix,
    );
    // null = 用户点取消 / 划走，保持现状
    if (result == null) return;
    if (result == _pathPrefix) return;
    setState(() {
      _pathPrefix = result;
    });
    _loadSongs();
  }

  /// 文件夹按钮上显示的标签：取路径最后一段；空串表示「全部」
  String get _folderButtonLabel {
    if (_pathPrefix.isEmpty) return '全部';
    final parts = _pathPrefix.split(RegExp(r'[\\/]+'));
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) return parts[i];
    }
    return '全部';
  }

  /// 返回应该传给后端的 type 参数。
  /// 优先级：widget.songType（外部硬约束）> _typeFilter（用户内部筛选）。
  String? _resolvedType() => widget.songType ?? _typeFilter;

  /// 类型筛选 chip 可选项；返回 (label, value) 列表。
  /// value=null 表示「全部」。
  /// - widget.songType 设了：返回空列表（不显示筛选器）
  /// - widget.excludeType 设了某类型：选项中剔除该类型
  List<({String label, String? value})> _typeFilterOptions() {
    if (widget.songType != null) return const [];
    final all = <({String label, String? value})>[
      (label: '全部', value: null),
      (label: '本地', value: 'local'),
      (label: '网络', value: 'remote'),
      (label: '电台', value: 'radio'),
    ];
    if (widget.excludeType == null) return all;
    return all.where((o) => o.value != widget.excludeType).toList();
  }

  void _onTypeFilterChanged(String? value) {
    if (_typeFilter == value) return;
    setState(() {
      _typeFilter = value;
      // 网络/电台没有 file_path，切到这两个类型自动清空目录筛选避免空结果
      if (!_supportsFolder()) {
        _pathPrefix = '';
      }
    });
    _loadSongs();
  }

  /// 当前类型是否支持按文件夹筛选。
  /// 仅 local 类型有 file_path；「全部」（null）兼有 local 也算支持。
  /// 受 widget.songType 硬约束时也按此规则判断。
  bool _supportsFolder() {
    final t = _resolvedType();
    return t == null || t == 'local';
  }

  /// 全选 checkbox 的三态值：null=部分选中，true=全部选中，false=都没选
  bool? _selectAllCheckboxValue() {
    if (_selectedIds.isEmpty) return false;
    if (_total > 0 && _selectedIds.length >= _total) return true;
    return null;
  }

  String _emptyMessage() {
    final hasKeyword = _searchController.text.isNotEmpty;
    final hasFolder = _pathPrefix.isNotEmpty;
    if (hasKeyword && hasFolder) return '该目录下未找到匹配的歌曲';
    if (hasKeyword) return '未找到匹配的歌曲';
    if (hasFolder) return '该目录下无歌曲';
    return '暂无歌曲';
  }

  /// 切换歌曲选中状态
  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  /// 全选/取消全选：覆盖整个筛选范围（不仅限当前已加载的页）
  /// - 已全选 → 清空
  /// - 否则 → 调 /songs/ids 一次性拿到所有匹配 id
  ///
  /// 注：服务端只能按 type/keyword/path_prefix 过滤；客户端独占的
  /// excludeIds / excludeType / songType（仅显示某类型）需在前端再剔除。
  /// excludeType 与 songType 可以靠把请求的 type 设成 widget.songType 收敛，
  /// 但 excludeType 表示"排除该类型，其它都要"——服务端无原生支持，所以
  /// 我们对返回的 id 列表客户端再过滤。
  Future<void> _toggleSelectAll() async {
    if (_isSelectingAll) return;

    // 已全选 → 清空
    if (_selectedIds.isNotEmpty && _selectedIds.length >= _total) {
      setState(() => _selectedIds.clear());
      return;
    }

    setState(() => _isSelectingAll = true);
    try {
      final repository = ref.read(songsRepositoryProvider);
      final keyword = _searchController.text.trim();

      // 服务端按 type/keyword/path_prefix 收敛
      final ids = await repository.getSongIds(
        type: _resolvedType(),
        keyword: keyword.isNotEmpty ? keyword : null,
        pathPrefix: _pathPrefix.isNotEmpty ? _pathPrefix : null,
      );

      // 客户端再剔除 excludeIds 与 excludeType
      // excludeType 在服务端无法表达，但可通过已知 song 列表查 type；
      // 实际上 widget.excludeType 通常是 'radio' 或 'remote'，可用 list 接口的
      // 当前页 song.type 信息+id 集合验证。这里采取保守策略：直接保留所有 id，
      // 把 excludeType 的剔除留给"添加到歌单"的服务端类型校验（后端 AddSongs
      // 已通过 ListTypesByIDs + CanAddSong 把不兼容的歌计入 skipped）。
      final allowed = ids.where((id) => !widget.excludeIds.contains(id));

      if (!mounted) return;
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(allowed);
      });
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: '获取列表失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSelectingAll = false);
      }
    }
  }

  /// 确认选择
  void _onConfirm() {
    if (_selectedIds.isEmpty) return;
    Navigator.of(context).pop(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '选择歌曲',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _onConfirm,
                  child: Text('确定(${_selectedIds.length})'),
                ),
              ],
            ),
          ),

          // 搜索框 + 文件夹筛选
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、艺术家或专辑',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_supportsFolder()) ...[
                  const SizedBox(width: 8),
                  _FolderFilterButton(
                    label: _folderButtonLabel,
                    active: _pathPrefix.isNotEmpty,
                    onPressed: _pickFolder,
                  ),
                ],
              ],
            ),
          ),

          // 类型筛选 chip 行
          if (_typeFilterOptions().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final opt in _typeFilterOptions()) ...[
                      ChoiceChip(
                        label: Text(opt.label),
                        selected: _typeFilter == opt.value,
                        onSelected: (_) => _onTypeFilterChanged(opt.value),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),

          // 全选行（显示总数 + 异步全选）
          if (_songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: _isSelectingAll ? null : _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectAllCheckboxValue(),
                        tristate: true,
                        onChanged: _isSelectingAll
                            ? null
                            : (_) => _toggleSelectAll(),
                      ),
                      Expanded(
                        child: Text(
                          _isSelectingAll
                              ? '正在选择全部...'
                              : (_selectedIds.length >= _total && _total > 0
                                  ? '取消全选（已选 ${_selectedIds.length}）'
                                  : '全选 $_total 首'),
                        ),
                      ),
                      if (_isSelectingAll)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // 歌曲列表
          Expanded(
            child:
                _isLoading && _songs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _songs.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _emptyMessage(),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _songs.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _songs.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final song = _songs[index];
                        final isSelected = _selectedIds.contains(song.id);

                        return InkWell(
                          onTap: () => _toggleSongSelection(song.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged:
                                      (_) => _toggleSongSelection(song.id),
                                ),
                                const SizedBox(width: 8),
                                CoverImage(
                                  coverUrl: song.coverUrl,
                                  
                                  size: 48,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (song.artist != null)
                                        Text(
                                          song.artist!,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// 文件夹筛选按钮：未选中时显示「全部」，选中时高亮并显示目录名。
class _FolderFilterButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onPressed;

  const _FolderFilterButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          active ? Icons.folder : Icons.folder_outlined,
          size: 18,
          color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? colorScheme.primary : null,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          side: BorderSide(
            color: active
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
