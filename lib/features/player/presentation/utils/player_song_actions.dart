import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
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

  final l10n = AppLocalizations.of(context);
  final result = await DeleteSongDialog.show(
    context,
    title: l10n.playerDeleteSongTitle,
    content: l10n.playerDeleteSongConfirm(song.title),
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
      ResponsiveSnackBar.showSuccess(context, message: l10n.playerSongDeleted);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ResponsiveSnackBar.showError(context, message: l10n.playerDeleteFailed);
    }
    return false;
  }
}
