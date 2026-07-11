import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/playlist/domain/playlist.dart';
import '../../features/playlist/presentation/providers/playlist_provider.dart';
import '../../l10n/app_localizations.dart';
import '../utils/responsive_snackbar.dart';
import 'cover_image.dart';
import 'loading_indicator.dart';

/// 添加歌曲到歌单的模态框
class AddToPlaylistModal extends ConsumerStatefulWidget {
  /// 要添加的歌曲 ID 列表
  final List<int> songIds;

  const AddToPlaylistModal({super.key, required this.songIds});

  /// 显示添加到歌单模态框
  static Future<void> show(BuildContext context, {required List<int> songIds}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddToPlaylistModal(songIds: songIds),
    );
  }

  @override
  ConsumerState<AddToPlaylistModal> createState() => _AddToPlaylistModalState();
}

class _AddToPlaylistModalState extends ConsumerState<AddToPlaylistModal> {
  bool _isAdding = false;

  /// 触底加载预留距离
  static const double _loadMoreThreshold = 200.0;

  /// 处理滚动通知，到底部时触发分页加载
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - _loadMoreThreshold) {
      ref.read(playlistListProvider(null).notifier).loadMore();
    }
    return false;
  }

  /// 底部加载更多指示器
  Widget _buildLoadMoreFooter(PaginatedPlaylistsState state) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed:
                () => ref.read(playlistListProvider(null).notifier).loadMore(),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.loadFailedTapRetry),
          ),
        ),
      );
    }
    if (!state.hasMore && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            l10n.loadedAllHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 添加歌曲到指定歌单
  Future<void> _addToPlaylist(Playlist playlist) async {
    setState(() => _isAdding = true);

    try {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final result = await notifier.addSongsToPlaylist(
        playlist.id,
        widget.songIds,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (result == null) {
        ResponsiveSnackBar.showError(context, message: l10n.addFailed);
      } else {
        Navigator.of(context).pop();
        final msg = result.skipped > 0
            ? l10n.addedToPlaylistWithSkip(
              result.added,
              playlist.name,
              result.skipped,
            )
            : l10n.addedToPlaylist(result.added, playlist.name);
        ResponsiveSnackBar.show(context, message: msg);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).addFailedDetail('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  /// 显示创建新歌单对话框
  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final l10n = AppLocalizations.of(context);

    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.newPlaylist),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.playlistNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(context).pop(trimmed);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = nameController.text.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(context).pop(trimmed);
                  }
                },
                child: Text(l10n.commonCreate),
              ),
            ],
          ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isAdding = true);

    try {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final newPlaylist = await notifier.createPlaylist(
        type: 'normal',
        name: name,
      );

      if (newPlaylist != null && mounted) {
        final result = await notifier.addSongsToPlaylist(
          newPlaylist.id,
          widget.songIds,
        );

        if (!mounted) return;
        if (result != null) {
          Navigator.of(context).pop();
          final l10n2 = AppLocalizations.of(context);
          final msg = result.skipped > 0
              ? l10n2.createdPlaylistWithSkip(name, result.added, result.skipped)
              : l10n2.createdPlaylistAdded(name, result.added);
          ResponsiveSnackBar.show(context, message: msg);
        }
      } else if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).createPlaylistFailed,
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).createPlaylistFailedDetail('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final playlistsAsync = ref.watch(playlistListProvider(null));

    return LoadingOverlay(
      isLoading: _isAdding,
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(l10n.addToPlaylist, style: theme.textTheme.titleLarge),
                    const Spacer(),
                    Text(
                      l10n.songsCount(widget.songIds.length),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 新建歌单
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: theme.colorScheme.primary),
                ),
                title: Text(l10n.newPlaylist),
                onTap: _isAdding ? null : _showCreatePlaylistDialog,
              ),
              const Divider(height: 1),
              // 歌单列表
              Expanded(
                child: playlistsAsync.when(
                  data: (state) {
                    final playlists = state.items;
                    if (playlists.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noPlaylists,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: ListView.builder(
                        controller: scrollController,
                        // +1 用于底部加载更多指示器
                        itemCount: playlists.length + 1,
                        itemBuilder: (context, index) {
                          if (index == playlists.length) {
                            return _buildLoadMoreFooter(state);
                          }
                          final playlist = playlists[index];
                          return ListTile(
                            leading: CoverImage(
                              coverUrl: playlist.coverImageUrl,
                              
                              size: 48,
                              placeholderIcon: Icons.playlist_play,
                            ),
                            title: Text(playlist.name),
                            subtitle: Text(
                              playlist.type == 'radio'
                                  ? l10n.songTypeRadio
                                  : l10n.navPlaylists,
                            ),
                            onTap:
                                _isAdding
                                    ? null
                                    : () => _addToPlaylist(playlist),
                          );
                        },
                      ),
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, stack) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.commonLoadFailed,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed:
                                  () => ref.invalidate(
                                    playlistListProvider(null),
                                  ),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.commonRetry),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
