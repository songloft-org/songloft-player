import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import 'song_cover_picker_modal.dart';

/// 歌单封面编辑的共享状态与逻辑。
///
/// 收敛「歌单编辑对话框」([PlaylistEditDialog]) 与「歌单表单对话框」
/// ([PlaylistFormDialog]) 之间逐字重复的封面选择/预览逻辑（本地上传 /
/// 从歌曲选择 / 清除 / 预览渲染）。两个对话框的保存模型不同（一个内部
/// 走 provider 保存、一个返回表单数据由调用方保存），故不合并为单一组件，
/// 仅共享这部分封面逻辑。
///
/// 子类通过 [coverInitialUrl] / [coverPickerPlaylistId] 提供各自的数据来源，
/// 通过 [coverPlaceholderIconSize] 覆盖占位图标尺寸。
mixin PlaylistCoverEditMixin<T extends StatefulWidget> on State<T> {
  /// 未修改时展示的原始封面 URL（各对话框数据来源不同）。
  String? get coverInitialUrl;

  /// 「从歌曲选择封面」使用的歌单 ID；为 null 时该功能不生效。
  int? get coverPickerPlaylistId;

  /// 占位图标尺寸，子类可覆盖。
  double get coverPlaceholderIconSize => 48;

  /// 封面选择模式：
  /// - null：未修改
  /// - 'local'：本地上传的图片
  /// - 'song'：从歌曲选择的封面
  /// - 'clear'：清除封面
  String? coverMode;
  PlatformFile? coverLocalFile;
  String? coverSelectedUrl;
  int? coverSelectedSongId;

  /// 当前预览的封面 URL
  String? get coverPreviewUrl {
    if (coverMode == 'clear') return null;
    if (coverMode == 'song') return coverSelectedUrl;
    if (coverMode == 'local') return coverLocalFile?.path;
    // 未修改时显示原有封面
    if (coverMode == null) return coverInitialUrl;
    return null;
  }

  /// 上传本地图片
  Future<void> pickCoverLocalImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          coverLocalFile = result.files.first;
          coverMode = 'local';
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
  Future<void> pickCoverFromSongs() async {
    final playlistId = coverPickerPlaylistId;
    if (playlistId == null) return;
    final result = await showSongCoverPicker(context, playlistId);
    if (result != null) {
      setState(() {
        coverSelectedSongId = result['songId'] as int?;
        coverSelectedUrl = result['coverUrl'] as String?;
        coverMode = 'song';
        coverLocalFile = null;
      });
    }
  }

  /// 清除封面
  void clearCoverSelection() {
    setState(() {
      coverMode = 'clear';
      coverLocalFile = null;
      coverSelectedUrl = null;
      coverSelectedSongId = null;
    });
  }

  /// 封面预览区渲染
  Widget buildCoverPreview(ColorScheme colorScheme) {
    // 本地文件预览
    if (coverMode == 'local' && coverLocalFile != null) {
      if (kIsWeb && coverLocalFile!.bytes != null) {
        return Image.memory(coverLocalFile!.bytes!, fit: BoxFit.cover);
      } else if (!kIsWeb && coverLocalFile!.path != null) {
        return Image.file(File(coverLocalFile!.path!), fit: BoxFit.cover);
      }
    }

    // 网络图片预览
    final previewUrl = coverPreviewUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return ExcludeSemantics(
        child: CachedNetworkImage(
          imageUrl: UrlHelper.buildCoverUrl(previewUrl),
          fit: BoxFit.cover,
          placeholder:
              (context, url) =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget:
              (context, url, error) => buildCoverPlaceholder(colorScheme),
        ),
      );
    }

    // 占位图
    return buildCoverPlaceholder(colorScheme);
  }

  Widget buildCoverPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: coverPlaceholderIconSize,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
