import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/delete_song_dialog.dart';
import '../../../library/presentation/providers/songs_provider.dart';
import '../providers/player_provider.dart';

Future<bool> deleteCurrentSongFromPlayer(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(playerStateProvider);
  final song = state.currentSong;
  if (song == null) return false;

  final result = await DeleteSongDialog.show(
    context,
    title: '删除歌曲',
    content: '确定要从歌曲库中删除「${song.title}」吗？',
  );
  if (result == null) return false;

  try {
    await ref
        .read(songsApiProvider)
        .deleteSong(song.id, deleteFiles: result.deleteFiles);
    final notifier = ref.read(playerStateProvider.notifier);
    notifier.removeFromPlaylist(state.currentIndex);
    final newState = ref.read(playerStateProvider);
    if (newState.currentSong != null) {
      await notifier.playSong(newState.currentSong!);
    }
    ref.invalidate(songsListProvider);
    if (context.mounted) {
      ResponsiveSnackBar.showSuccess(context, message: '歌曲已删除');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ResponsiveSnackBar.showError(context, message: '删除失败');
    }
    return false;
  }
}
