import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../l10n/l10n_holder.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../playlist/data/playlist_api.dart';
import '../../../playlist/domain/playlist.dart';

/// 内置收藏歌单名称
const String _favoriteSongPlaylistName = '收藏';
const String _favoriteRadioPlaylistName = '电台收藏';

/// 收藏状态
class FavoriteState {
  final Set<int> favoriteSongIds;
  final Set<int> favoriteRadioIds;
  final int? favoriteSongPlaylistId;
  final int? favoriteRadioPlaylistId;
  final bool initialized;
  final bool isLoading;
  final String? error;

  const FavoriteState({
    this.favoriteSongIds = const {},
    this.favoriteRadioIds = const {},
    this.favoriteSongPlaylistId,
    this.favoriteRadioPlaylistId,
    this.initialized = false,
    this.isLoading = false,
    this.error,
  });

  FavoriteState copyWith({
    Set<int>? favoriteSongIds,
    Set<int>? favoriteRadioIds,
    int? favoriteSongPlaylistId,
    int? favoriteRadioPlaylistId,
    bool? initialized,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FavoriteState(
      favoriteSongIds: favoriteSongIds ?? this.favoriteSongIds,
      favoriteRadioIds: favoriteRadioIds ?? this.favoriteRadioIds,
      favoriteSongPlaylistId:
          favoriteSongPlaylistId ?? this.favoriteSongPlaylistId,
      favoriteRadioPlaylistId:
          favoriteRadioPlaylistId ?? this.favoriteRadioPlaylistId,
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 收藏状态管理器
class FavoriteNotifier extends Notifier<FavoriteState> {
  late PlaylistApi _playlistApi;
  bool _disposed = false;

  @override
  FavoriteState build() {
    _playlistApi = ref.watch(favoritePlaylistApiProvider);
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
    });

    // 仅在已认证时自动调度初始化，避免在 auth unknown 阶段发起无效 API 请求
    final authStatus = ref.watch(authStateProvider.select((s) => s.status));
    if (authStatus == AuthStatus.authenticated) {
      Future.microtask(() => initialize());
    }

    return const FavoriteState();
  }

  /// 初始化：查找或创建内置收藏歌单
  /// 幂等操作，多次调用不会重复创建歌单
  Future<void> initialize() async {
    // 如果已经初始化或正在加载，直接返回
    if (state.initialized || state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. 获取所有歌单
      final response = await _playlistApi.getPlaylists(limit: 1000);
      if (_disposed) return;
      final playlists = response.playlists;

      // 2. 查找歌曲收藏歌单（优先查找内置的）
      Playlist? songFavorite = _findPlaylist(
        playlists,
        _favoriteSongPlaylistName,
        'normal',
      );

      // 3. 查找电台收藏歌单（优先查找内置的）
      Playlist? radioFavorite = _findPlaylist(
        playlists,
        _favoriteRadioPlaylistName,
        'radio',
      );

      // 4. 如果歌曲收藏歌单不存在，创建它
      if (songFavorite == null) {
        songFavorite = await _playlistApi.createPlaylist(
          type: 'normal',
          name: _favoriteSongPlaylistName,
          description: '我喜欢的歌曲',
        );
        if (_disposed) return;
      }

      // 5. 如果电台收藏歌单不存在，创建它
      if (radioFavorite == null) {
        radioFavorite = await _playlistApi.createPlaylist(
          type: 'radio',
          name: _favoriteRadioPlaylistName,
          description: '我喜欢的电台',
        );
        if (_disposed) return;
      }

      // 6. 加载收藏歌单中的歌曲 ID
      final songIds = await _loadPlaylistSongIds(songFavorite.id);
      if (_disposed) return;
      final radioIds = await _loadPlaylistSongIds(radioFavorite.id);
      if (_disposed) return;

      state = state.copyWith(
        favoriteSongPlaylistId: songFavorite.id,
        favoriteRadioPlaylistId: radioFavorite.id,
        favoriteSongIds: songIds,
        favoriteRadioIds: radioIds,
        initialized: true,
        isLoading: false,
      );
    } catch (e) {
      if (_disposed) return;
      debugPrint('[Favorite] initialize error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 查找歌单（优先查找内置的，然后按名称和类型查找）
  Playlist? _findPlaylist(List<Playlist> playlists, String name, String type) {
    // 优先查找内置的
    for (final p in playlists) {
      if (p.labels.contains('built_in') && p.name == name) {
        return p;
      }
    }
    // 按名称和类型查找
    for (final p in playlists) {
      if (p.name == name && p.type == type) {
        return p;
      }
    }
    return null;
  }

  /// 加载歌单中的所有歌曲 ID（分页加载，确保大歌单也能完整加载）
  Future<Set<int>> _loadPlaylistSongIds(int playlistId) async {
    const pageLimit = 500;
    final allIds = <int>{};
    int offset = 0;
    try {
      while (true) {
        final response = await _playlistApi.getPlaylistSongs(
          playlistId,
          limit: pageLimit,
          offset: offset,
        );
        if (response.songs.isEmpty) break;
        allIds.addAll(response.songs.map((s) => s.id));
        offset += response.songs.length;
        if (offset >= response.total) break;
      }
    } catch (e) {
      // 返回已加载的部分
    }
    return allIds;
  }

  /// 切换歌曲收藏状态
  Future<bool> toggleFavorite(int songId) async {
    if (state.favoriteSongPlaylistId == null) {
      await initialize();
    }

    if (state.favoriteSongPlaylistId == null) {
      throw Exception(l10n.libraryFavoritePlaylistNotFound);
    }

    final isFavorited = state.favoriteSongIds.contains(songId);

    try {
      if (isFavorited) {
        await _playlistApi.removeSongFromPlaylist(
          state.favoriteSongPlaylistId!,
          songId,
        );
        state = state.copyWith(
          favoriteSongIds: Set<int>.from(state.favoriteSongIds)..remove(songId),
        );
        return false;
      } else {
        await _playlistApi.addSongsToPlaylist(state.favoriteSongPlaylistId!, [
          songId,
        ]);
        state = state.copyWith(
          favoriteSongIds: Set<int>.from(state.favoriteSongIds)..add(songId),
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 切换电台收藏状态
  Future<bool> toggleRadioFavorite(int radioId) async {
    if (state.favoriteRadioPlaylistId == null) {
      await initialize();
    }

    if (state.favoriteRadioPlaylistId == null) {
      throw Exception(l10n.libraryRadioFavoritePlaylistNotFound);
    }

    final isFavorited = state.favoriteRadioIds.contains(radioId);

    try {
      if (isFavorited) {
        await _playlistApi.removeSongFromPlaylist(
          state.favoriteRadioPlaylistId!,
          radioId,
        );
        state = state.copyWith(
          favoriteRadioIds: Set<int>.from(state.favoriteRadioIds)
            ..remove(radioId),
        );
        return false;
      } else {
        await _playlistApi.addSongsToPlaylist(state.favoriteRadioPlaylistId!, [
          radioId,
        ]);
        state = state.copyWith(
          favoriteRadioIds: Set<int>.from(state.favoriteRadioIds)..add(radioId),
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 检查歌曲是否已收藏
  bool isFavorite(int songId) => state.favoriteSongIds.contains(songId);

  /// 检查电台是否已收藏
  bool isRadioFavorite(int radioId) => state.favoriteRadioIds.contains(radioId);

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Favorite API Provider
final favoritePlaylistApiProvider = Provider<PlaylistApi>((ref) {
  final dio = ref.watch(dioProvider);
  return PlaylistApi(dio);
});

/// Favorite NotifierProvider
final favoriteProvider = NotifierProvider<FavoriteNotifier, FavoriteState>(
  FavoriteNotifier.new,
);

/// 便捷 Provider：检查歌曲是否已收藏
final isSongFavoritedProvider = Provider.family<bool, int>((ref, songId) {
  final state = ref.watch(favoriteProvider);
  return state.favoriteSongIds.contains(songId);
});

/// 便捷 Provider：检查电台是否已收藏
final isRadioFavoritedProvider = Provider.family<bool, int>((ref, radioId) {
  final state = ref.watch(favoriteProvider);
  return state.favoriteRadioIds.contains(radioId);
});
