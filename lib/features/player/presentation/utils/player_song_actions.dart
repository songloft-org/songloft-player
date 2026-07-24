import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/song_cache_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/delete_song_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../library/presentation/providers/songs_provider.dart';
import '../../../settings/presentation/providers/song_cache_provider.dart';
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

/// 把一首歌手动缓存到本机（songloft-org/songloft#312）。
///
/// 视频歌曲缓存前弹体积提示；缓存音质取当前播放音质设置；超本地上限时提示。
Future<void> cacheSongToDevice(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(context);

  if (song.isVideo) {
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.songCacheVideoWarnTitle,
      content: l10n.songCacheVideoWarnContent,
      confirmText: l10n.songCacheConfirm,
    );
    if (!ok) return;
  }

  final prefs = await ref.read(appPreferencesProvider.future);
  final quality = prefs.getAudioQuality();
  final maxSize = prefs.getLocalCacheMaxSize();

  if (context.mounted) {
    ResponsiveSnackBar.show(
      context,
      message: l10n.songCacheStarted(song.title),
    );
  }

  try {
    await ref
        .read(songCacheProvider.notifier)
        .cacheSong(song, quality: quality, maxSize: maxSize);
    if (context.mounted) {
      ResponsiveSnackBar.showSuccess(context, message: l10n.songCacheDone);
    }
  } on SongCacheLimitExceeded {
    if (context.mounted) {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.songCacheLimitExceeded,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ResponsiveSnackBar.showError(context, message: l10n.songCacheFailed);
    }
  }
}

/// 从本机缓存删除一首歌。
Future<void> removeSongFromDevice(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(context);
  await ref.read(songCacheProvider.notifier).removeSong(song.id);
  if (context.mounted) {
    ResponsiveSnackBar.showSuccess(context, message: l10n.songCacheRemoved);
  }
}

/// 打开「歌曲信息」弹窗：码率/格式/采样率/大小/类型/播放来源/缓存位置。
///
/// [playbackSource] 传入当前播放来源（来自 PlayerState）；非播放中的歌传 null。
void showSongInfoDialog(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  PlaybackSource? playbackSource,
}) {
  showDialog<void>(
    context: context,
    builder:
        (context) =>
            _SongInfoDialog(song: song, playbackSource: playbackSource),
  );
}

class _SongInfoDialog extends ConsumerWidget {
  final Song song;
  final PlaybackSource? playbackSource;

  const _SongInfoDialog({required this.song, this.playbackSource});

  String _typeLabel(AppLocalizations l10n) {
    switch (song.type) {
      case 'radio':
        return l10n.songTypeRadioLabel;
      case 'remote':
        return l10n.songTypeRemoteLabel;
      default:
        return l10n.songTypeLocalLabel;
    }
  }

  String _bitRateLabel() {
    if (song.bitRate <= 0) return '—';
    final kbps =
        song.bitRate >= 1000 ? (song.bitRate / 1000).round() : song.bitRate;
    return '$kbps kbps';
  }

  String _sampleRateLabel() {
    if (song.sampleRate <= 0) return '—';
    return '${(song.sampleRate / 1000).toStringAsFixed(1)} kHz';
  }

  String _sourceLabel(AppLocalizations l10n, bool cached) {
    // 未在播放时，用缓存状态推断来源展示。
    final src = playbackSource;
    if (src == PlaybackSource.localCache) return l10n.songInfoSourceLocal;
    if (src == PlaybackSource.remoteStream) return l10n.songInfoSourceRemote;
    return cached ? l10n.songInfoSourceLocal : l10n.songInfoSourceUnknown;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // watch 修订号，缓存增删后刷新缓存位置行。
    ref.watch(songCacheProvider);
    final entry = ref.read(songCacheProvider.notifier).entry(song.id);
    final cached = entry != null;

    final rows = <(String, String)>[
      if (song.artist != null && song.artist!.isNotEmpty)
        (l10n.songInfoArtist, song.artist!),
      if (song.album != null && song.album!.isNotEmpty)
        (l10n.songInfoAlbum, song.album!),
      (l10n.songInfoType, _typeLabel(l10n)),
      if (song.format != null && song.format!.isNotEmpty)
        (l10n.songInfoFormat, song.format!.toUpperCase()),
      (l10n.songInfoBitRate, _bitRateLabel()),
      (l10n.songInfoSampleRate, _sampleRateLabel()),
      if (song.fileSize > 0)
        (l10n.songInfoFileSize, Formatters.formatFileSize(song.fileSize)),
      (l10n.songInfoPlaybackSource, _sourceLabel(l10n, cached)),
      if (cached) (l10n.songInfoCachePath, entry.path),
    ];

    return AlertDialog(
      title: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(value, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            if (cached) ...[
              const SizedBox(height: 8),
              Text(
                l10n.songInfoQualityNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
