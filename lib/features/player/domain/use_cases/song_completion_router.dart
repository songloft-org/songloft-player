import '../player_state.dart';

/// Action the player should take when the current song completes naturally.
enum CompletionAction {
  /// Replay the current song from the beginning (single-loop mode).
  replayCurrent,

  /// Pause playback without advancing (single-play mode).
  pause,

  /// Advance to the next song in the queue.
  playNext,

  /// Stop playback because the end of the playlist has been reached (order
  /// mode, last song).
  stopEndOfList,
}

/// Pure-domain router that decides the next action when a song finishes
/// playing.
///
/// Extracted from [PlayerNotifier._onSongCompleted] to allow unit testing
/// without Flutter/Riverpod dependencies.
class SongCompletionRouter {
  /// Resolves the completion action based on the current [mode], the
  /// [currentIndex] in the playlist, and the total [playlistLength].
  CompletionAction resolve({
    required PlayMode mode,
    required int currentIndex,
    required int playlistLength,
    bool hasPriorityNext = false,
  }) {
    if (hasPriorityNext && playlistLength > 0) return CompletionAction.playNext;
    switch (mode) {
      case PlayMode.single:
        return CompletionAction.replayCurrent;
      case PlayMode.singlePlay:
        return CompletionAction.pause;
      case PlayMode.order:
        if (currentIndex >= playlistLength - 1) {
          return CompletionAction.stopEndOfList;
        }
        return CompletionAction.playNext;
      case PlayMode.loop:
        return CompletionAction.playNext;
      case PlayMode.random:
        return CompletionAction.playNext;
    }
  }
}
