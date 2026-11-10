import 'dart:async';

/// Callback to find or create the built-in favorite playlist.
/// Returns the playlist ID.
typedef FindOrCreatePlaylist = Future<int> Function();

/// Callback to load all song IDs in a playlist (handles pagination internally).
typedef LoadPlaylistSongIds = Future<Set<int>> Function(int playlistId);

/// Callback to add a song to a playlist.
typedef AddSongToPlaylist = Future<void> Function(int playlistId, int songId);

/// Callback to remove a song from a playlist.
typedef RemoveSongFromPlaylist =
    Future<void> Function(int playlistId, int songId);

/// Pure-Dart domain service that manages favorite song/radio IDs.
///
/// This class encapsulates the business logic for:
/// - Finding or creating the built-in favorite playlists
/// - Loading all favorited song/radio IDs
/// - Toggling favorite state (add/remove)
///
/// It does NOT depend on Flutter, Riverpod, or Dio. All I/O is injected via
/// function callbacks.
class FavoriteService {
  final Set<int> _favoriteIds = {};
  int? _playlistId;
  bool _initializing = false;
  int _generation = 0;

  /// Whether this service has been successfully initialized.
  bool get isInitialized => _playlistId != null;

  /// The playlist ID used by this service, or null if not yet initialized.
  int? get playlistId => _playlistId;

  /// An unmodifiable view of the current favorite IDs.
  Set<int> get favoriteIds => Set<int>.unmodifiable(_favoriteIds);

  /// Check if a song is favorited.
  /// Returns false if not yet initialized.
  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  /// Initialize the service: find or create the favorite playlist, then load
  /// all song IDs into memory.
  ///
  /// This is idempotent — calling it when already initialized or currently
  /// initializing is a no-op.
  ///
  /// Throws if [findOrCreatePlaylist] or [loadSongIds] throws.
  Future<void> initialize({
    required FindOrCreatePlaylist findOrCreatePlaylist,
    required LoadPlaylistSongIds loadSongIds,
  }) async {
    if (_playlistId != null || _initializing) return;
    _initializing = true;
    final generation = _generation;
    try {
      final id = await findOrCreatePlaylist();
      if (generation != _generation) return;
      final ids = await loadSongIds(id);
      if (generation != _generation) return;
      _playlistId = id;
      _favoriteIds
        ..clear()
        ..addAll(ids);
    } finally {
      if (generation == _generation) _initializing = false;
    }
  }

  /// Toggle the favorite state of [songId].
  ///
  /// - If currently favorited: calls [removeSong] and returns `false`.
  /// - If not currently favorited: calls [addSong] and returns `true`.
  ///
  /// Throws [StateError] if the service is not initialized.
  /// Rethrows any error from the add/remove callbacks (the local set is NOT
  /// modified on failure).
  Future<bool> toggle({
    required int songId,
    required AddSongToPlaylist addSong,
    required RemoveSongFromPlaylist removeSong,
  }) async {
    if (_playlistId == null) {
      throw StateError(
        'FavoriteService is not initialized. Call initialize() first.',
      );
    }

    final playlistId = _playlistId!;

    if (_favoriteIds.contains(songId)) {
      await removeSong(playlistId, songId);
      _favoriteIds.remove(songId);
      return false;
    } else {
      await addSong(playlistId, songId);
      _favoriteIds.add(songId);
      return true;
    }
  }

  /// Reload all favorite IDs from the backend.
  ///
  /// Throws [StateError] if not initialized.
  Future<void> refresh({required LoadPlaylistSongIds loadSongIds}) async {
    if (_playlistId == null) {
      throw StateError(
        'FavoriteService is not initialized. Call initialize() first.',
      );
    }
    final ids = await loadSongIds(_playlistId!);
    _favoriteIds
      ..clear()
      ..addAll(ids);
  }

  /// Directly update the favorite IDs set (used by host bridge notifications).
  void updateIds(Set<int> ids) {
    _favoriteIds
      ..clear()
      ..addAll(ids);
  }

  /// Reset internal state (useful when user logs out).
  void reset() {
    _generation++;
    _favoriteIds.clear();
    _playlistId = null;
    _initializing = false;
  }
}
