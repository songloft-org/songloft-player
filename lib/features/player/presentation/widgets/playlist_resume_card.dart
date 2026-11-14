import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';
import '../../data/playlist_progress_sync.dart';
import '../providers/player_provider.dart';

final playlistProgressProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, id) async {
      final timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return PlaylistProgressSync(ref.read(playlistApiProvider).dio).read(id);
    });

class PlaylistResumeCard extends ConsumerWidget {
  const PlaylistResumeCard({
    super.key,
    required this.id,
    required this.audiobook,
    this.onLocate,
  });
  final int id;
  final bool audiobook;
  final Future<void> Function(int)? onLocate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playlistProgressProvider(id)).value;
    final l10n = AppLocalizations.of(context);
    if (data == null) return const SizedBox.shrink();
    if (data['invalid'] == true) return Text(l10n.playlistProgressInvalid);
    if (data['song'] == null) return const SizedBox.shrink();
    final seconds = ((data['position_ms'] as int? ?? 0) / 1000).floor();
    return ListTile(
      trailing:
          onLocate == null
              ? null
              : IconButton(
                tooltip: l10n.playlistLocateResume,
                icon: const Icon(Icons.my_location),
                onPressed: () => onLocate?.call(data['song']['id'] as int),
              ),
      leading: const Icon(Icons.play_arrow),
      title: Text(
        data['completed'] == true
            ? l10n.playlistFinished
            : audiobook
            ? l10n.playlistContinueBook
            : l10n.playlistContinue,
      ),
      subtitle: Text(
        '${data['song']['title']} · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
      ),
      onTap: () async {
        try {
          await ref
              .read(playerStateProvider.notifier)
              .playPlaylistTarget(
                playlistId: id,
                resume: data['completed'] != true,
              );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
    );
  }
}
