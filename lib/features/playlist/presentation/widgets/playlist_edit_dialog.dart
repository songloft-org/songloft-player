import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../domain/playlist.dart';
import '../providers/playlist_provider.dart';
import 'song_cover_picker_modal.dart';

class PlaylistEditDialog extends ConsumerStatefulWidget {
  final Playlist playlist;
  final int playlistId;

  const PlaylistEditDialog({super.key, required this.playlist, required this.playlistId});

  @override
  ConsumerState<PlaylistEditDialog> createState() =>
      PlaylistEditDialogState();
}

class PlaylistEditDialogState extends ConsumerState<PlaylistEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  /// 封面选择模式
  /// null: 未修改
  /// 'local': 本地上传的图片
  /// 'song': 从歌曲选择的封面
  /// 'clear': 清除封面
  String? _coverMode;

  /// 本地选择的文件
  PlatformFile? _localFile;

  /// 从歌曲选择的封面信息
  String? _selectedCoverUrl;
  int? _selectedCoverSongId;

  /// 是否正在保存
  bool _isSaving = false;

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

  /// 获取当前预览的封面 URL
  String? get _previewCoverUrl {
    if (_coverMode == 'clear') return null;
    if (_coverMode == 'song') {
      return _selectedCoverUrl;
    }
    if (_coverMode == 'local') {
      return _localFile?.path;
    }
    // 未修改时显示原有封面
    if (_coverMode == null) {
      return widget.playlist.coverUrl;
    }
    return null;
  }

  /// 上传本地图片
  Future<void> _pickLocalImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _localFile = result.files.first;
          _coverMode = 'local';
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).playlistPickImageFailed('$e'),
        );
      }
    }
  }

  /// 从歌曲选择封面
  Future<void> _pickFromSongs() async {
    final result = await showSongCoverPicker(context, widget.playlistId);
    if (result != null) {
      setState(() {
        _selectedCoverSongId = result['songId'] as int?;
        _selectedCoverUrl = result['coverUrl'] as String?;
        _coverMode = 'song';
        _localFile = null;
      });
    }
  }

  /// 清除封面
  void _clearCover() {
    setState(() {
      _coverMode = 'clear';
      _localFile = null;
      _selectedCoverUrl = null;
      _selectedCoverSongId = null;
    });
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
      if (_coverMode == 'local' && _localFile != null) {
        final file = _localFile!;
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
      } else if (_coverMode == 'song' && _selectedCoverSongId != null) {
        // 从歌曲选择的封面
        await notifier.updatePlaylist(
          widget.playlistId,
          name: name,
          description: description.isEmpty ? null : description,
          coverSongId: _selectedCoverSongId,
        );
      } else if (_coverMode == 'clear') {
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
        _coverMode != 'clear' &&
        (_coverMode == 'local' ||
            _coverMode == 'song' ||
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
                child: _buildCoverPreview(colorScheme),
              ),
              const SizedBox(height: 12),
              // 封面操作按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickLocalImage,
                    icon: const Icon(Icons.upload, size: 18),
                    label: Text(l10n.playlistUploadImage),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickFromSongs,
                    icon: const Icon(Icons.music_note, size: 18),
                    label: Text(l10n.playlistPickFromSongs),
                  ),
                  if (hasCover)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _clearCover,
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

  Widget _buildCoverPreview(ColorScheme colorScheme) {
    // 本地文件预览
    if (_coverMode == 'local' && _localFile != null) {
      if (kIsWeb && _localFile!.bytes != null) {
        return Image.memory(_localFile!.bytes!, fit: BoxFit.cover);
      } else if (!kIsWeb && _localFile!.path != null) {
        return Image.file(File(_localFile!.path!), fit: BoxFit.cover);
      }
    }

    // 网络图片预览
    final previewUrl = _previewCoverUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return ExcludeSemantics(
        child: CachedNetworkImage(
          imageUrl: UrlHelper.buildCoverUrl(previewUrl),
          fit: BoxFit.cover,
          placeholder:
              (context, url) =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (context, url, error) => _buildPlaceholder(colorScheme),
        ),
      );
    }

    // 占位图
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: 48,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
