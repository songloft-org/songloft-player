import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/audio_track_provider.dart';

/// 音轨切换入口按钮（songloft-org/songloft#297）。
///
/// 仅当当前歌曲的可选音轨数 > 1 时显示（如双音轨 mka：原唱 / 伴奏）。点击弹出底部抽屉
/// 列出各音轨，选择即通过 libmpv 原生切轨、即时生效。Web 无 media_kit Player，音轨列表恒空，
/// 本按钮自动隐藏（音轨切换在 Web 属已知限制）。
class AudioTrackControl extends ConsumerWidget {
  /// 图标尺寸，跟随各布局的工具行风格。
  final double iconSize;

  /// 视觉密度：默认 null（标准 48×48 触摸区），与相邻的普通 IconButton 对齐，
  /// 避免在 spaceEvenly/spaceAround 均分行里因本按钮偏窄导致间距不均。
  /// 仅当所在行的兄弟按钮整体为 compact（如 desktop_player 次要操作行）时才显式传 compact 保持一致。
  final VisualDensity? visualDensity;

  const AudioTrackControl({
    super.key,
    this.iconSize = 20,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackState = ref.watch(audioTrackProvider);
    if (!trackState.hasMultiple) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return IconButton(
      onPressed: () => showAudioTrackSheet(context, ref),
      icon: Icon(
        Icons.multitrack_audio_rounded,
        size: iconSize,
        color: theme.colorScheme.primary,
      ),
      tooltip: AppLocalizations.of(context).playerAudioTrack,
      visualDensity: visualDensity,
    );
  }
}

/// 音轨可读标签：优先 title（如「原唱」「伴奏」），其次 language，最后回退「音轨 N」。
String audioTrackLabel(BuildContext context, AudioTrack track, int index) {
  final title = track.title;
  if (title != null && title.trim().isNotEmpty) return title.trim();
  final lang = track.language;
  if (lang != null && lang.trim().isNotEmpty) return lang.trim();
  return AppLocalizations.of(context).playerAudioTrackNumbered(index + 1);
}

/// 弹出音轨选择底部抽屉。供 [AudioTrackControl] 与 TV 布局的音轨按钮共用。
Future<void> showAudioTrackSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final l10n = AppLocalizations.of(context);
          final trackState = ref.watch(audioTrackProvider);
          final tracks = trackState.tracks;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.playerSelectAudioTrack,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (var i = 0; i < tracks.length; i++)
                _AudioTrackTile(
                  label: audioTrackLabel(context, tracks[i], i),
                  selected: trackState.isCurrent(tracks[i]),
                  onTap: () {
                    ref
                        .read(audioTrackProvider.notifier)
                        .selectTrack(tracks[i]);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      );
    },
  );
}

class _AudioTrackTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AudioTrackTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: color,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}
