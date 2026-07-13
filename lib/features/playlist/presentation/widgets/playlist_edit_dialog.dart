import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../domain/playlist.dart';
import '../providers/playlist_provider.dart';
import 'playlist_cover_edit_mixin.dart';

class PlaylistEditDialog extends ConsumerStatefulWidget {
  final Playlist playlist;
  final int playlistId;

  const PlaylistEditDialog({
    super.key,
    required this.playlist,
    required this.playlistId,
  });

  @override
  ConsumerState<PlaylistEditDialog> createState() => PlaylistEditDialogState();
}

class PlaylistEditDialogState extends ConsumerState<PlaylistEditDialog>
    with PlaylistCoverEditMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  /// 是否正在保存
  bool _isSaving = false;

  @override
  String? get coverInitialUrl => widget.playlist.coverUrl;

  @override
  int? get coverPickerPlaylistId => widget.playlistId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _descController = TextEditingController(text: widget.playlist.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 保存
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ResponsiveSnackBar.showError(context, message: l10n.playlistNameRequired);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final description = _descController.text.trim();
      // 处理封面上传
      if (coverMode == 'local' && coverLocalFile != null) {
        final file = coverLocalFile!;
        final uploadedPlaylist = await notifier.uploadPlaylistCover(
          widget.playlistId,
          bytes: file.bytes,
          filePath: file.path,
          fileName: file.name,
        );
        if (uploadedPlaylist == null) {
          if (mounted) {
            ResponsiveSnackBar.showError(
              context,
              message: l10n.playlistCoverUploadFailed,
            );
          }
          return;
        }
        // 上传成功后更新其他信息，同时传递封面信息防止被后端覆盖
        await notifier.updatePlaylist(
          widget.playlistId,
          name: name,
          description: description.isEmpty ? null : description,
        );
      } else if (coverMode == 'song' && coverSelectedSongId != null) {
        // 从歌曲选择的封面
        await notifier.updatePlaylist(
          widget.playlistId,
          name: name,
          description: description.isEmpty ? null : description,
          coverSongId: coverSelectedSongId,
        );
      } else if (coverMode == 'clear') {
        // 清除封面
        await notifier.updatePlaylist(
          widget.playlistId,
          name: name,
          description: description.isEmpty ? null : description,
          coverPath: '',
        );
      } else {
        // 未修改封面，只更新名称和描述
        await notifier.updatePlaylist(
          widget.playlistId,
          name: name,
          description: description.isEmpty ? null : description,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playlistSaveFailed('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasCover =
        coverMode != 'clear' &&
        (coverMode == 'local' ||
            coverMode == 'song' ||
            widget.playlist.coverUrl?.isNotEmpty == true);
    return AlertDialog(
      title: Text(
        widget.playlist.isBuiltIn
            ? l10n.playlistEditCover
            : l10n.playlistEditPlaylist,
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 封面预览区域
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: buildCoverPreview(colorScheme),
              ),
              const SizedBox(height: 12),
              // 封面操作按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : pickCoverLocalImage,
                    icon: const Icon(Icons.upload, size: 18),
                    label: Text(l10n.playlistUploadImage),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : pickCoverFromSongs,
                    icon: const Icon(Icons.music_note, size: 18),
                    label: Text(l10n.playlistPickFromSongs),
                  ),
                  if (hasCover)
                    TextButton.icon(
                      onPressed: _isSaving ? null : clearCoverSelection,
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      label: Text(
                        l10n.playlistClear,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 歌单名称
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.playlistNameLabel,
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isSaving && !widget.playlist.isBuiltIn,
              ),
              const SizedBox(height: 16),
              // 歌单描述
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: l10n.playlistDescLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isSaving && !widget.playlist.isBuiltIn,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(l10n.playlistSave),
        ),
      ],
    );
  }
}
