import 'dart:async';

import '../../../shared/widgets/network_cover_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/color_extraction.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/mixins/song_list_actions.dart';
import '../../../shared/widgets/song_picker_modal.dart';
import '../../library/presentation/providers/songs_provider.dart';
import '../../library/presentation/song_edit_page.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';
import 'widgets/playlist_edit_dialog.dart';
import 'widgets/playlist_song_tile.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../l10n/app_localizations.dart';

/// 歌单详情页面
class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage>
    with SongListActions {
  int get _playlistIdInt => int.tryParse(widget.playlistId) ?? 0;

  /// 触底加载预留距离
  static const double _loadMoreThreshold = 300.0;

  late final ScrollController _scrollController;

  /// 排序模式
  bool _isSortMode = false;

  /// 多选模式
  bool _isSelectMode = false;

  /// 多选模式下选中的歌曲 ID
  final Set<int> _selectedSongIds = {};

  /// 排序模式下的可排序歌曲列表（本地副本）
  List<Song> _sortableSongs = [];

  /// 搜索状态
  bool _isSearchMode = false;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(playlistSongsProvider(_playlistIdInt).notifier).search(value);
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        _debounceTimer?.cancel();
        ref.read(playlistSongsProvider(_playlistIdInt).notifier).search('');
      }
    });
  }

  /// 滚动监听：接近底部时触发分页加载
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadMore();
    }
  }

  /// 进入排序模式（确保所有歌曲已加载）
  Future<void> _enterSortMode(List<Song> songs) async {
    // 手动排序需要全部歌曲在内存中
    await ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadAll();
    if (!mounted) return;
    final fullSongs =
        ref.read(playlistSongsProvider(_playlistIdInt)).value?.items ?? songs;
    setState(() {
      _isSortMode = true;
      _isSelectMode = false;
      _selectedSongIds.clear();
      _sortableSongs = List.from(fullSongs);
    });
  }

  /// 退出排序模式并保存
  Future<void> _exitSortMode() async {
    final songIds = _sortableSongs.map((s) => s.id).toList();
    setState(() => _isSortMode = false);

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylistSongs(
      _playlistIdInt,
      songIds,
    );

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ref.read(playlistSongsProvider(_playlistIdInt).notifier).resetFilter();
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistSortSaved);
      } else {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playlistSortSaveFailed,
        );
      }
    }
  }

  /// 自动按名称排序
  Future<void> _autoSortByName(
    List<Song> songs, {
    bool ascending = true,
  }) async {
    // 排序需要全部歌曲在内存中
    await ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadAll();
    if (!mounted) return;
    final fullSongs =
        ref.read(playlistSongsProvider(_playlistIdInt)).value?.items ?? songs;

    final sorted = List<Song>.from(fullSongs);
    sorted.sort((a, b) {
      final result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return ascending ? result : -result;
    });

    final songIds = sorted.map((s) => s.id).toList();

    // 检查排序前后是否有变化，避免无意义的 API 调用
    final originalIds = fullSongs.map((s) => s.id).toList();
    if (listEquals(songIds, originalIds)) {
      if (mounted) {
        ResponsiveSnackBar.show(
          context,
          message: AppLocalizations.of(context).playlistAlreadySortedSongs,
        );
      }
      return;
    }

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylistSongs(
      _playlistIdInt,
      songIds,
    );

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ref.read(playlistSongsProvider(_playlistIdInt).notifier).resetFilter();
        ResponsiveSnackBar.showSuccess(
          context,
          message: ascending
              ? l10n.playlistSortedByNameAsc
              : l10n.playlistSortedByNameDesc,
        );
      } else {
        ResponsiveSnackBar.showError(context, message: l10n.playlistSortFailed);
      }
    }
  }

  /// 提取标题中第一个出现的数字（支持开头和中间位置）
  /// 例如: "04.校园故事" → 4, "干得漂亮 | 01 好意被辜负" → 1
  /// 如果没有数字，返回 null
  int? _extractFirstNumber(String title) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// 自动按数字前缀排序
  Future<void> _autoSortByNumberPrefix(List<Song> songs) async {
    // 排序需要全部歌曲在内存中
    await ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadAll();
    if (!mounted) return;
    final fullSongs =
        ref.read(playlistSongsProvider(_playlistIdInt)).value?.items ?? songs;

    final sorted = List<Song>.from(fullSongs);
    sorted.sort((a, b) {
      final numA = _extractFirstNumber(a.title);
      final numB = _extractFirstNumber(b.title);

      // 都有数字前缀：按数值排序
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
        // 数值相同时按标题字母序
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      // 有数字前缀的排在前面
      if (numA != null) return -1;
      if (numB != null) return 1;
      // 都没有数字前缀：按标题字母序
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    final songIds = sorted.map((s) => s.id).toList();

    // 检查排序前后是否有变化
    final originalIds = fullSongs.map((s) => s.id).toList();
    if (listEquals(songIds, originalIds)) {
      if (mounted) {
        ResponsiveSnackBar.show(
          context,
          message: AppLocalizations.of(context).playlistAlreadySortedSongs,
        );
      }
      return;
    }

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylistSongs(
      _playlistIdInt,
      songIds,
    );

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ref.read(playlistSongsProvider(_playlistIdInt).notifier).resetFilter();
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistSortedByNumber,
        );
      } else {
        ResponsiveSnackBar.showError(context, message: l10n.playlistSortFailed);
      }
    }
  }

  /// 比较两个整数列表是否相等
  /// 取消排序模式（不保存）
  void _cancelSortMode() {
    setState(() {
      _isSortMode = false;
      _sortableSongs = [];
    });
  }

  /// 进入多选模式
  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
      _isSortMode = false;
      _selectedSongIds.clear();
      _sortableSongs = [];
    });
  }

  /// 退出多选模式
  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedSongIds.clear();
    });
  }

  /// 切换歌曲选中状态
  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll(List<Song> songs) {
    setState(() {
      if (_selectedSongIds.length == songs.length) {
        _selectedSongIds.clear();
      } else {
        _selectedSongIds.addAll(songs.map((s) => s.id));
      }
    });
  }

  /// 批量删除选中的歌曲
  Future<void> _batchRemoveSelectedSongs() async {
    if (_selectedSongIds.isEmpty) return;

    final count = _selectedSongIds.length;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlistBatchRemoveTitle),
            content: Text(l10n.playlistBatchRemoveConfirm(count)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.playlistRemove),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.batchRemoveSongs(
      _playlistIdInt,
      _selectedSongIds,
    );

    if (mounted) {
      if (success) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistRemovedCount(count),
        );
        _exitSelectMode();
      } else {
        ResponsiveSnackBar.showError(context, message: l10n.playlistRemoveFailed);
      }
    }
  }

  /// 拖拽排序回调（onReorderItem：newIndex 已是移除后的最终目标索引）
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _sortableSongs.removeAt(oldIndex);
      _sortableSongs.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistDetailProvider(_playlistIdInt));
    final songsAsync = ref.watch(playlistSongsProvider(_playlistIdInt));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playlistDetailProvider(_playlistIdInt));
          ref.invalidate(playlistSongsProvider(_playlistIdInt));
        },
        child: playlistAsync.when(
          data: (playlist) => _buildContent(context, playlist, songsAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildError(error.toString()),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    // 全站统一的双栏（主从）布局判断，见 context.useWideLayout
    final useWideLayout = context.useWideLayout;
    if (useWideLayout) {
      return _buildWideContent(context, playlist, songsAsync);
    }

    return _buildNarrowContent(context, playlist, songsAsync);
  }

  /// 窄屏布局（Mobile / Tablet / Auto）：单列 CustomScrollView
  Widget _buildNarrowContent(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 顶栏：使用主题色，不受封面影响
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          title: Text(playlist.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppLocalizations.of(context).playlistBack,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/playlists');
              }
            },
          ),
          actions: _buildAppBarActions(
            context,
            playlist,
            songsAsync,
            colorScheme,
          ),
        ),

        // 封面 header 区域（独立于顶栏）
        SliverToBoxAdapter(
          child: _buildCoverHeader(context, playlist),
        ),

        // 歌单信息
        SliverToBoxAdapter(
          child: _buildPlaylistInfo(context, playlist, songsAsync),
        ),

        // 操作按钮
        SliverToBoxAdapter(
          child: _buildActionButtons(context, playlist, songsAsync),
        ),

        // 搜索栏
        if (_isSearchMode)
          SliverToBoxAdapter(child: _buildSearchBar(context)),

        // 歌曲列表
        songsAsync.when(
          data: (state) => _buildSongList(context, playlist, state.items),
          loading:
              () => SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (int i = 0; i < 5; i++) SkeletonLoader.listTile(),
                  ],
                ),
              ),
          error:
              (error, stack) =>
                  SliverToBoxAdapter(child: _buildError(error.toString())),
        ),

        // 加载更多指示器
        if (songsAsync.value != null)
          SliverToBoxAdapter(
            child: _buildSongsLoadMoreIndicator(songsAsync.value!),
          ),

        // 底部安全区域
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
        ),
      ],
    );
  }

  /// 宽屏布局（Desktop / TV）：左右分栏
  Widget _buildWideContent(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 顶栏
        AppBar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          title: Text(playlist.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: AppLocalizations.of(context).playlistBack,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/playlists');
              }
            },
          ),
          actions: _buildAppBarActions(
            context,
            playlist,
            songsAsync,
            colorScheme,
          ),
        ),
        // 左右分栏
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左栏：封面 + 歌单信息 + 操作按钮
              SizedBox(
                width: 320,
                child: _buildWideLeftPanel(context, playlist, songsAsync),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
              // 右栏：歌曲列表
              Expanded(
                child: _buildWideRightPanel(context, playlist, songsAsync),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 宽屏左栏：封面 + 歌单信息 + 操作按钮（固定不滚动或轻量滚动）
  Widget _buildWideLeftPanel(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = playlist.coverUrl;
    final paletteAsync = ref.watch(coverColorsProvider(coverUrl));
    final palette = paletteAsync.value;
    final bgColor =
        palette?.darkMutedColor ?? colorScheme.surfaceContainerHighest;

    final songCount = songsAsync.value?.total ?? 0;
    final songs = songsAsync.value?.items ?? [];

    // 构建信息片段
    final infoParts = <String>[];
    final l10n = AppLocalizations.of(context);
    if (playlist.type == 'radio') infoParts.add(l10n.songTypeRadio);
    for (final label in playlist.labels) {
      infoParts.add(_getLabelName(label));
    }
    infoParts.add(l10n.songsCount(songCount));
    final subtitle = infoParts.join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 封面
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: AppRadius.xlAll,
              boxShadow: AppShadows.medium,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: playlist.coverImageUrl != null
                ? ExcludeSemantics(
                    child: NetworkCoverImage(
                      imageUrl: UrlHelper.buildCoverUrl(
                        playlist.coverImageUrl!,
                      ),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) =>
                          _buildCoverPlaceholder(colorScheme, playlist),
                    ),
                  )
                : _buildCoverPlaceholder(colorScheme, playlist),
          ),
          const SizedBox(height: AppSpacing.lg),
          // 歌单名称
          Text(
            playlist.name,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // 描述
          if (playlist.description?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              playlist.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // 标签 / 歌曲数
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 操作按钮（纵向全宽排列）
          if (!_isSortMode && !_isSelectMode) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    songs.isEmpty ? null : () => _playAll(playlist, songs),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.playlistPlayAll),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addSongs,
                icon: const Icon(Icons.add),
                label: Text(l10n.playlistAddSongs),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 宽屏右栏：歌曲列表（含搜索栏、分页加载）
  Widget _buildWideRightPanel(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 搜索栏
            if (_isSearchMode)
              SliverToBoxAdapter(child: _buildSearchBar(context)),

            // 歌曲列表
            songsAsync.when(
              data: (state) => _buildSongList(context, playlist, state.items),
              loading: () => SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (int i = 0; i < 5; i++) SkeletonLoader.listTile(),
                  ],
                ),
              ),
              error: (error, stack) =>
                  SliverToBoxAdapter(child: _buildError(error.toString())),
            ),

            // 加载更多指示器
            if (songsAsync.value != null)
              SliverToBoxAdapter(
                child: _buildSongsLoadMoreIndicator(songsAsync.value!),
              ),

            // 底部安全区域
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建歌曲分页加载更多指示器
  Widget _buildSongsLoadMoreIndicator(PaginatedSongsState state) {
    // 排序模式 / 多选模式下不显示加载更多（避免影响交互）
    if (_isSortMode || _isSelectMode) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed:
                () =>
                    ref
                        .read(playlistSongsProvider(_playlistIdInt).notifier)
                        .loadMore(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.playlistLoadMoreRetry),
          ),
        ),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!state.hasMore && state.items.isNotEmpty && state.total > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.playlistAllLoaded(state.total),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 构建封面 header 区域（位于顶栏下方，不会覆盖顶栏）
  Widget _buildCoverHeader(BuildContext context, Playlist playlist) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = context.isWideScreen;
    final coverUrl = playlist.coverUrl;
    final paletteAsync = ref.watch(coverColorsProvider(coverUrl));
    final palette = paletteAsync.value;

    final coverSize = isWide ? 180.0 : 140.0;
    final bgColor = palette?.darkMutedColor ?? colorScheme.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgColor.withValues(alpha: 0.6),
            colorScheme.surface,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isWide ? AppSpacing.lg : AppSpacing.md,
      ),
      child: Center(
        child: Container(
          width: coverSize,
          height: coverSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.medium,
          ),
          clipBehavior: Clip.antiAlias,
          child: playlist.coverImageUrl != null
              ? ExcludeSemantics(
                child: NetworkCoverImage(
                    imageUrl: UrlHelper.buildCoverUrl(playlist.coverImageUrl!),
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: colorScheme.surfaceContainerHighest),
                    errorWidget: (context, url, error) =>
                        _buildCoverPlaceholder(colorScheme, playlist),
                  ),
                )
              : _buildCoverPlaceholder(colorScheme, playlist),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme, Playlist playlist) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
          size: 64,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildPlaylistInfo(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final songCount = songsAsync.value?.total ?? 0;

    // 构建信息片段
    final infoParts = <String>[];
    final l10n = AppLocalizations.of(context);
    if (playlist.type == 'radio') infoParts.add(l10n.songTypeRadio);
    for (final label in playlist.labels) {
      infoParts.add(_getLabelName(label));
    }
    infoParts.add(l10n.songsCount(songCount));
    final subtitle = infoParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描述（如果有）
          if (playlist.description?.isNotEmpty == true) ...[
            Text(
              playlist.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // 聚合副标题
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 AppBar 操作按钮（使用主题色，不依赖封面调色板）
  List<Widget> _buildAppBarActions(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final songs = songsAsync.value?.items ?? [];
    final totalSongs = songsAsync.value?.total ?? songs.length;
    final isBuiltIn = playlist.isBuiltIn;

    // 排序模式
    if (_isSortMode) {
      return [
        TextButton(
          onPressed: _cancelSortMode,
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _exitSortMode,
          child: Text(l10n.playlistDone),
        ),
      ];
    }

    // 多选模式
    if (_isSelectMode) {
      return [
        TextButton(
          onPressed: () async {
            await ref
                .read(playlistSongsProvider(_playlistIdInt).notifier)
                .loadAll();
            if (!mounted) return;
            final fullSongs =
                ref.read(playlistSongsProvider(_playlistIdInt)).value?.items ??
                songs;
            _toggleSelectAll(fullSongs);
          },
          child: Text(
            _selectedSongIds.length == totalSongs
                ? l10n.playlistDeselectAll
                : l10n.selectAll,
          ),
        ),
        PopupMenuButton<String>(
          enabled: _selectedSongIds.isNotEmpty,
          onSelected: (value) {
            if (value == 'remove') {
              _batchRemoveSelectedSongs();
            } else if (value == 'delete') {
              _batchDeleteSelectedSongsFromLibrary();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'remove',
              child: Text(l10n.playlistRemoveFromPlaylist),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                l10n.playlistDeleteFromLibrary,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l10n.playlistActionsCount(_selectedSongIds.length),
              style: TextStyle(
                color: _selectedSongIds.isEmpty
                    ? colorScheme.onSurface.withValues(alpha: 0.38)
                    : colorScheme.primary,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: _exitSelectMode,
          child: Text(l10n.commonCancel),
        ),
      ];
    }

    final currentSort = songsAsync.value?.sort ?? 'position';
    final hasKeyword = (songsAsync.value?.keyword ?? '').isNotEmpty;

    // 正常模式
    return [
      IconButton(
        icon: Icon(_isSearchMode ? Icons.search_off : Icons.search),
        tooltip: l10n.playlistSearch,
        onPressed: _toggleSearch,
      ),
      if (songs.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l10n.playlistMultiSelect,
          onPressed: _enterSelectMode,
        ),
      if (totalSongs > 1)
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: l10n.playlistSort,
          onSelected: (value) {
            final notifier =
                ref.read(playlistSongsProvider(_playlistIdInt).notifier);
            switch (value) {
              // 视图排序（非破坏性）
              case 'view_position':
                notifier.setSort('position', 'asc');
                break;
              case 'view_added_at':
                notifier.setSort('added_at', 'desc');
                break;
              case 'view_file_modified_at':
                notifier.setSort('file_modified_at', 'desc');
                break;
              case 'view_title':
                notifier.setSort('title', 'asc');
                break;
              case 'view_artist':
                notifier.setSort('artist', 'asc');
                break;
              case 'view_duration':
                notifier.setSort('duration', 'asc');
                break;
              // 永久排序
              case 'perm_name_asc':
                _autoSortByName(songs, ascending: true);
                break;
              case 'perm_name_desc':
                _autoSortByName(songs, ascending: false);
                break;
              case 'perm_number':
                _autoSortByNumberPrefix(songs);
                break;
              case 'manual':
                _enterSortMode(songs);
                break;
            }
          },
          itemBuilder:
              (context) => [
                _buildSortMenuItem(
                  value: 'view_position',
                  icon: Icons.reorder,
                  title: l10n.playlistSortCustom,
                  isSelected: currentSort == 'position',
                ),
                _buildSortMenuItem(
                  value: 'view_added_at',
                  icon: Icons.schedule,
                  title: l10n.playlistSortRecentlyAdded,
                  isSelected: currentSort == 'added_at',
                ),
                _buildSortMenuItem(
                  value: 'view_file_modified_at',
                  icon: Icons.insert_drive_file_outlined,
                  title: l10n.playlistSortFileTime,
                  isSelected: currentSort == 'file_modified_at',
                ),
                _buildSortMenuItem(
                  value: 'view_title',
                  icon: Icons.sort_by_alpha,
                  title: l10n.playlistSortTitle,
                  isSelected: currentSort == 'title',
                ),
                _buildSortMenuItem(
                  value: 'view_artist',
                  icon: Icons.person,
                  title: l10n.playlistSortArtist,
                  isSelected: currentSort == 'artist',
                ),
                _buildSortMenuItem(
                  value: 'view_duration',
                  icon: Icons.timer,
                  title: l10n.playlistSortDuration,
                  isSelected: currentSort == 'duration',
                ),
                const PopupMenuDivider(),
                if (!hasKeyword) ...[
                  PopupMenuItem(
                    value: 'perm_name_asc',
                    child: ListTile(
                      leading: const Icon(Icons.sort_by_alpha),
                      title: Text(l10n.playlistSortNameAsc),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'perm_name_desc',
                    child: ListTile(
                      leading: const Icon(Icons.sort_by_alpha),
                      title: Text(l10n.playlistSortNameDesc),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'perm_number',
                    child: ListTile(
                      leading: const Icon(Icons.format_list_numbered),
                      title: Text(l10n.playlistSortNumberPrefix),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (currentSort == 'position')
                    PopupMenuItem(
                      value: 'manual',
                      child: ListTile(
                        leading: const Icon(Icons.drag_handle),
                        title: Text(l10n.playlistSortManual),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ],
        ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'add_songs':
              _addSongs();
              break;
            case 'edit':
              _showEditDialog(playlist);
              break;
            case 'delete':
              _confirmDelete(playlist);
              break;
          }
        },
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: 'add_songs',
                child: ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l10n.playlistAddSongs),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(
                    isBuiltIn ? l10n.playlistEditCover : l10n.playlistEditPlaylist,
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (!isBuiltIn) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: colorScheme.error),
                    title: Text(
                      l10n.playlistDelete,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
      ),
    ];
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.clearSearch,
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(
                          playlistSongsProvider(_playlistIdInt).notifier,
                        )
                        .search('');
                  },
                )
              : null,
          hintText: l10n.playlistSearchHint,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Playlist playlist,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final songs = songsAsync.value?.items ?? [];

    // 排序模式和多选模式下隐藏操作按钮
    if (_isSortMode || _isSelectMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // 播放全部按钮：限制最大宽度，但允许自适应
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive<double>(
                  mobile: 200,
                  tablet: 240,
                  desktop: 280,
                  tv: 320,
                ),
              ),
              child: FilledButton.icon(
                onPressed:
                    songs.isEmpty ? null : () => _playAll(playlist, songs),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.playlistPlayAll),
                style: FilledButton.styleFrom(
                  minimumSize: context.responsiveButtonMinSize,
                ),
              ),
            ),
          ),
          // 添加歌曲按钮
          ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _addSongs,
              icon: const Icon(Icons.add),
              label: Text(l10n.playlistAddSongs),
              style: OutlinedButton.styleFrom(
                minimumSize: context.responsiveButtonMinSize,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSongList(
    BuildContext context,
    Playlist playlist,
    List<Song> songs,
  ) {
    final isBuiltIn = playlist.isBuiltIn;

    if (songs.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptySongs(context, isBuiltIn));
    }

    // 排序模式：使用 ReorderableListView
    if (_isSortMode) {
      return SliverToBoxAdapter(
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sortableSongs.length,
          onReorderItem: _onReorder,
          itemBuilder: (context, index) {
            final song = _sortableSongs[index];
            return PlaylistSongTile(
              key: ValueKey(song.id),
              song: song,
              index: index + 1,
              onTap: () {},
              onRemove: () {},
              showDragHandle: true,
              showTrailing: false,
            );
          },
        ),
      );
    }

    // 多选模式：显示 Checkbox
    if (_isSelectMode) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final song = songs[index];
          final isSelected = _selectedSongIds.contains(song.id);
          return PlaylistSongTile(
            song: song,
            index: index + 1,
            onTap: () => _toggleSongSelection(song.id),
            onRemove: () {},
            showCheckbox: true,
            isChecked: isSelected,
            onCheckChanged: (checked) => _toggleSongSelection(song.id),
            showTrailing: false,
          );
        }, childCount: songs.length),
      );
    }

    // 正常模式
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = songs[index];
        return PlaylistSongTile(
          song: song,
          index: index + 1,
          onTap: () => _playSong(song, songs, index),
          onRemove: () => _removeSong(playlist.id, song),
          onDeleteFromLibrary: () => _deleteSongFromLibrary(song),
          onEdit: () => _navigateToEditSong(song),
          onLongPress: () {
            _enterSelectMode();
            _toggleSongSelection(song.id);
          },
        );
      }, childCount: songs.length),
    );
  }

  Widget _buildEmptySongs(BuildContext context, bool isBuiltIn) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.music_off_outlined,
      title: l10n.playlistEmptySongs,
      subtitle: l10n.playlistEmptySongsSubtitle,
      action: FilledButton.tonal(
        onPressed: _addSongs,
        child: Text(l10n.playlistAddSongs),
      ),
    );
  }

  Widget _buildError(String error) {
    return ErrorView(
      message: error,
      onRetry: () {
        ref.invalidate(playlistDetailProvider(_playlistIdInt));
        ref.invalidate(playlistSongsProvider(_playlistIdInt));
      },
    );
  }

  String _getLabelName(String label) {
    final l10n = AppLocalizations.of(context);
    switch (label) {
      case 'built_in':
        return l10n.playlistLabelBuiltIn;
      case 'auto_created':
        return l10n.playlistLabelAutoCreated;
      default:
        return label;
    }
  }

  /// 显示编辑对话框
  Future<void> _showEditDialog(Playlist playlist) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => PlaylistEditDialog(
            playlist: playlist,
            playlistId: _playlistIdInt,
          ),
    );

    if (result == true && mounted) {
      // 强制刷新歌单详情并等待完成，确保封面等变更立即生效
      ref.invalidate(coverColorsProvider(playlist.coverUrl));
      ref.invalidate(playlistDetailProvider(_playlistIdInt));
      await ref.read(playlistDetailProvider(_playlistIdInt).future);
    }
  }

  /// 添加歌曲
  Future<void> _addSongs() async {
    // 先确保已加载全部歌曲，得到完整的 excludeIds 防止重复添加
    await ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadAll();
    if (!mounted) return;
    final currentSongs = ref.read(playlistSongsProvider(_playlistIdInt));
    final excludeIds =
        currentSongs.value?.items.map((s) => s.id).toSet() ?? <int>{};

    // 获取歌单类型，决定歌曲过滤：
    // - 电台歌单：只显示 radio 类型歌曲
    // - 非电台歌单：排除 radio 类型歌曲
    final playlist = ref.read(playlistDetailProvider(_playlistIdInt)).value;
    final isRadioPlaylist = playlist?.type == 'radio';

    // 打开歌曲选择器
    final selectedIds = await SongPickerModal.show(
      context,
      excludeIds: excludeIds,
      songType: isRadioPlaylist ? 'radio' : null,
      excludeType: isRadioPlaylist ? null : 'radio',
    );

    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;

    // 添加歌曲到歌单
    final notifier = ref.read(playlistNotifierProvider.notifier);
    final result = await notifier.addSongsToPlaylist(
      _playlistIdInt,
      selectedIds,
    );

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (result == null) {
      ResponsiveSnackBar.showError(context, message: l10n.playlistAddSongsFailed);
      return;
    }
    final msg = result.skipped > 0
        ? l10n.playlistAddedWithSkipped(result.added, result.skipped)
        : l10n.playlistAddedCount(result.added);
    ResponsiveSnackBar.showSuccess(context, message: msg);
  }

  /// 确认删除歌单
  Future<void> _confirmDelete(Playlist playlist) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlistConfirmDelete),
            content: Text(l10n.playlistDeleteConfirm(playlist.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.deletePlaylist(playlist.id);

      if (success && mounted) {
        // 安全返回：检查是否有可弹出的路由
        if (context.canPop()) {
          context.pop();
        } else {
          // 没有返回栈时，跳转到歌单列表页
          context.go('/playlists');
        }
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistDeleted);
      }
    }
  }

  /// 播放全部（委托给 PlayerNotifier.playPlaylistById）
  Future<void> _playAll(Playlist playlist, List<Song> songs) async {
    final l10n = AppLocalizations.of(context);
    if (songs.isEmpty) {
      ResponsiveSnackBar.show(context, message: l10n.playlistEmpty);
      return;
    }
    final total = await ref
        .read(playerStateProvider.notifier)
        .playPlaylistById(playlist.id);
    if (!mounted) return;
    if (total < 0) {
      ResponsiveSnackBar.showError(context, message: l10n.playlistPlayFailed);
    } else if (total == 0) {
      ResponsiveSnackBar.show(context, message: l10n.playlistEmpty);
    } else {
      ResponsiveSnackBar.show(
        context,
        message: l10n.playlistPlayingCount(total),
      );
    }
  }

  /// 播放单曲
  void _playSong(Song song, List<Song> songs, int index) {
    debugPrint('[Player] Play song: ${song.title} at index $index');
    // 从已加载分页开始播放并后台补齐整个歌单队列，避免队列被截断到已加载页
    // （songloft-org/songloft#299）。
    final state = ref.read(playlistSongsProvider(_playlistIdInt)).value;
    ref.read(playerStateProvider.notifier).playPlaylistFromLoaded(
          loadedSongs: songs,
          startIndex: index,
          playlistId: _playlistIdInt,
          total: state?.total ?? songs.length,
          sort: state?.sort ?? 'position',
          order: state?.order ?? 'asc',
          keyword: state?.keyword ?? '',
        );
    ResponsiveSnackBar.show(
      context,
      message: AppLocalizations.of(context).playlistPlayingSong(song.title),
    );
  }

  /// 从歌单移除歌曲
  Future<void> _removeSong(int playlistId, Song song) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlistRemoveSongTitle),
            content: Text(l10n.playlistRemoveSongConfirm(song.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.playlistRemove),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.removeSongFromPlaylist(
        playlistId,
        song.id,
      );

      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistSongRemoved,
        );
      }
    }
  }

  /// 编辑歌曲（跳转编辑页，返回后刷新歌单歌曲列表与曲库）
  Future<void> _navigateToEditSong(Song song) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditPage(song: song, songType: song.type),
      ),
    );
    if (result == true) {
      ref.invalidate(playlistSongsProvider(_playlistIdInt));
      ref.invalidate(songsListProvider);
    }
  }

  Future<void> _deleteSongFromLibrary(Song song) async {
    final l10n = AppLocalizations.of(context);
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.playlistDeleteSong,
      content: l10n.playlistDeleteSongConfirm(song.title),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(songsApiProvider)
          .deleteSong(song.id, deleteFiles: result.deleteFiles);
      ref.invalidate(playlistSongsProvider(_playlistIdInt));
      ref.invalidate(songsListProvider);
      removeDeletedSongsFromPlayerQueue({song.id});
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistSongDeleted);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: l10n.playlistDeleteFailed);
      }
    }
  }

  Future<void> _batchDeleteSelectedSongsFromLibrary() async {
    if (_selectedSongIds.isEmpty) return;

    final count = _selectedSongIds.length;
    final ids = _selectedSongIds.toSet();
    final l10n = AppLocalizations.of(context);
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.playlistBatchDelete,
      content: l10n.playlistBatchDeleteSongsConfirm(count),
    );
    if (result == null || !mounted) return;

    try {
      final api = ref.read(songsApiProvider);
      final deleted = await api.batchDeleteSongs(
        ids.toList(),
        deleteFiles: result.deleteFiles,
      );
      ref.invalidate(playlistSongsProvider(_playlistIdInt));
      ref.invalidate(songsListProvider);
      removeDeletedSongsFromPlayerQueue(ids);
      _exitSelectMode();
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistDeletedSongsCount(deleted),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: l10n.playlistDeleteFailed);
      }
    }
  }

}
