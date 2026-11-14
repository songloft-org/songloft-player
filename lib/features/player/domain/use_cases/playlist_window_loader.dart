import '../../../../shared/models/song.dart';

/// Keeps the visible queue contiguous while prioritizing the target and its next tracks.
Future<bool> loadPlaylistWindow({
  required int targetIndex,
  required int total,
  required Future<List<Song>> Function(int offset, int limit) fetch,
  required void Function(
    List<Song> songs, {
    required bool initial,
    required bool complete,
  })
  onWindow,
  required bool Function() isCurrent,
}) async {
  if (targetIndex < 0 || targetIndex >= total) {
    throw StateError('Track removed from playlist');
  }
  Future<List<Song>?> request(int offset, int count) async {
    for (var attempt = 0; ; attempt++) {
      if (!isCurrent()) return null;
      try {
        final songs = await fetch(offset, count);
        if (!isCurrent()) return null;
        if (songs.length != count) {
          throw StateError('Playlist changed while loading');
        }
        return songs;
      } catch (_) {
        if (!isCurrent()) return null;
        if (attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  var start = targetIndex > 0 ? targetIndex - 1 : 0;
  final initial = await request(start, (total - start).clamp(0, 100));
  if (initial == null) return false;
  var window = initial;
  var end = start + window.length;
  onWindow(window, initial: true, complete: start == 0 && end == total);
  while (end < total) {
    final batch = await request(end, (total - end).clamp(0, 100));
    if (batch == null) return false;
    window = [...window, ...batch];
    end += batch.length;
    onWindow(window, initial: false, complete: start == 0 && end == total);
  }
  while (start > 0) {
    final next = (start - 100).clamp(0, start);
    final batch = await request(next, start - next);
    if (batch == null) return false;
    window = [...batch, ...window];
    start = next;
    onWindow(window, initial: false, complete: start == 0);
  }
  return isCurrent();
}
