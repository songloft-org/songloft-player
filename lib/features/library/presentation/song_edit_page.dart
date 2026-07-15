import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import 'providers/songs_provider.dart';

/// 编辑/添加网络歌曲或电台，以及编辑本地歌曲的页面
class SongEditPage extends ConsumerStatefulWidget {
  final Song? song;
  final String songType; // 'remote' / 'radio' / 'local'（本地仅编辑）

  const SongEditPage({super.key, this.song, required this.songType});

  @override
  ConsumerState<SongEditPage> createState() => _SongEditPageState();
}

class _SongEditPageState extends ConsumerState<SongEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _urlController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _durationController;
  late final TextEditingController _lyricUrlController;
  bool _isSubmitting = false;
  bool _renameFile = true; // 本地歌曲：改标题时同步重命名文件，默认开启
  bool _isVideo = false; // 网络歌曲/电台：是否含视频画面（不走扫描 ffprobe，需手动声明）

  bool get isEditMode => widget.song != null;
  bool get isRadio => widget.songType == AppConstants.songTypeRadio;
  bool get isLocal => widget.songType == AppConstants.songTypeLocal;

  /// 插件音源网络歌曲：DB 的 url 为空（靠 source_data 播放），序列化后 source_url 也为空。
  /// 这类歌曲没有可编辑的直链 URL，编辑时隐藏 URL 字段、也不回传 url，
  /// 避免把内部播放端点（/api/v1/songs/{id}/play）当作源地址写回 DB。
  bool get isPluginRemote =>
      isEditMode &&
      widget.song?.type == AppConstants.songTypeRemote &&
      (widget.song?.sourceUrl == null || widget.song!.sourceUrl!.isEmpty);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _artistController = TextEditingController(text: widget.song?.artist ?? '');
    _albumController = TextEditingController(text: widget.song?.album ?? '');
    // 仅用 source_url（原始源地址）；不要 fallback 到 song.url，
    // 因为 song.url 是内部播放端点（/api/v1/songs/{id}/play），并非可编辑的源 URL。
    _urlController = TextEditingController(text: widget.song?.sourceUrl ?? '');
    _coverUrlController = TextEditingController(
      text: widget.song?.sourceCoverUrl ?? '',
    );
    _durationController = TextEditingController(
      text: widget.song?.duration.toStringAsFixed(0) ?? '',
    );
    _lyricUrlController = TextEditingController(
      text: widget.song?.lyricRemoteUrl ?? '',
    );
    _isVideo = widget.song?.isVideo ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _urlController.dispose();
    _coverUrlController.dispose();
    _durationController.dispose();
    _lyricUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode
              ? (isLocal
                  ? l10n.libraryEditLocalSong
                  : (isRadio
                      ? l10n.libraryEditRadio
                      : l10n.libraryEditRemoteSong))
              : (isRadio ? l10n.libraryAddRadio : l10n.libraryAddRemoteSong),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(l10n.librarySave),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 短域 URL 只读信息区（仅编辑模式）
              if (isEditMode) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLocal
                              ? l10n.libraryFileInfoReadonly
                              : l10n.libraryServerEndpointReadonly,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (isLocal)
                          _buildReadOnlyUrlRow(
                            l10n.libraryReadonlyFile,
                            widget.song!.filePath,
                          )
                        else ...[
                          _buildReadOnlyUrlRow(l10n.libraryPlay, widget.song!.url),
                          if (widget.song!.coverUrl != null &&
                              widget.song!.coverUrl!.isNotEmpty)
                            _buildReadOnlyUrlRow(
                              l10n.libraryReadonlyCover,
                              widget.song!.coverUrl!,
                            ),
                          if (widget.song!.lyricUrl != null &&
                              widget.song!.lyricUrl!.isNotEmpty)
                            _buildReadOnlyUrlRow(
                              l10n.libraryReadonlyLyric,
                              widget.song!.lyricUrl!,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 标题
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.libraryEditTitleLabel,
                  hintText: l10n.libraryEditTitleRequired,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.libraryEditTitleRequired;
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 艺术家
              TextFormField(
                controller: _artistController,
                decoration: InputDecoration(
                  labelText: l10n.libraryColumnArtist,
                  hintText: l10n.libraryEditArtistHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 专辑（仅网络歌曲与本地歌曲，电台除外）
              if (!isRadio) ...[
                TextFormField(
                  controller: _albumController,
                  decoration: InputDecoration(
                    labelText: l10n.libraryColumnAlbum,
                    hintText: l10n.libraryEditAlbumHint,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
              ],

              // 同步重命名文件（仅本地歌曲）
              if (isLocal) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _renameFile,
                  onChanged: (v) => setState(() => _renameFile = v),
                  title: Text(l10n.libraryRenameFileTitle),
                  subtitle: Text(l10n.libraryRenameFileSubtitle),
                ),
                const SizedBox(height: 8),
              ],

              // 以下字段仅网络歌曲/电台可编辑，本地歌曲隐藏
              if (!isLocal) ...[
                // URL（插件音源歌曲没有可编辑直链，隐藏此字段）
                if (!isPluginRemote) ...[
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: isEditMode
                          ? l10n.libraryEditSourceUrlLabel
                          : l10n.libraryEditUrlLabel,
                      hintText: l10n.libraryEditUrlHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.libraryEditUrlRequired;
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme) {
                        return l10n.libraryEditUrlInvalid;
                      }
                      return null;
                    },
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                ],

                // 封面 URL
                TextFormField(
                  controller: _coverUrlController,
                  decoration: InputDecoration(
                    labelText: isEditMode
                        ? l10n.libraryEditSourceCoverUrlLabel
                        : l10n.libraryEditCoverUrlLabel,
                    hintText: l10n.libraryEditCoverUrlHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 时长（仅网络歌曲）
                if (!isRadio) ...[
                  TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: l10n.libraryEditDurationLabel,
                      hintText: l10n.libraryEditDurationHint,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                ],

                // 歌词 URL（仅网络歌曲）
                if (!isRadio) ...[
                  TextFormField(
                    controller: _lyricUrlController,
                    decoration: InputDecoration(
                      labelText: isEditMode
                          ? l10n.libraryEditLyricRemoteUrlLabel
                          : l10n.libraryEditLyricUrlLabel,
                      hintText: l10n.libraryEditLyricUrlHint,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                ],

                // 是否视频内容（网络歌曲/电台通用；不走扫描 ffprobe，需手动声明）
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isVideo,
                  onChanged: (v) => setState(() => _isVideo = v),
                  title: Text(l10n.libraryVideoToggleTitle),
                  subtitle: Text(l10n.libraryVideoToggleSubtitle),
                ),
                const SizedBox(height: 8),
              ],

              // 封面预览
              Builder(
                builder: (context) {
                  final previewUrl = isEditMode
                      ? (widget.song?.coverUrl ?? '')
                      : _coverUrlController.text;
                  if (previewUrl.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      Text(l10n.libraryCoverPreview),
                      const SizedBox(height: 8),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ExcludeSemantics(
                            child: Image.network(
                              UrlHelper.buildCoverUrl(previewUrl),
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, _, _) => Container(
                                    width: 150,
                                    height: 150,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 48,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyUrlRow(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ResponsiveSnackBar.show(
                context,
                message: AppLocalizations.of(context).libraryCopied,
              );
            },
            tooltip: AppLocalizations.of(context).libraryCopy,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(songsRepositoryProvider);

      if (isEditMode && isLocal) {
        // 本地歌曲：把 title/artist/album 写入文件标签 + DB，并按开关同步重命名文件
        await repository.writeSongTags(
          widget.song!.id,
          title: _titleController.text.trim(),
          artist: _artistController.text.trim(),
          album: _albumController.text.trim(),
          renameFile: _renameFile,
        );
      } else if (isEditMode) {
        // 更新歌曲
        await repository.updateSong(
          widget.song!.id,
          title: _titleController.text.trim(),
          artist:
              _artistController.text.trim().isEmpty
                  ? null
                  : _artistController.text.trim(),
          album:
              isRadio
                  ? null
                  : (_albumController.text.trim().isEmpty
                      ? null
                      : _albumController.text.trim()),
          // 插件音源歌曲无可编辑直链，不回传 url（后端保留原值，避免污染源地址）。
          url: isPluginRemote ? null : _urlController.text.trim(),
          coverUrl:
              _coverUrlController.text.trim().isEmpty
                  ? null
                  : _coverUrlController.text.trim(),
          duration:
              isRadio ? null : (double.tryParse(_durationController.text)),
          isLive: null,
          isVideo: _isVideo,
        );

        // 歌词 URL 变化时单独更新
        if (!isRadio) {
          final newLyricUrl = _lyricUrlController.text.trim();
          final oldLyricUrl = widget.song?.lyricRemoteUrl ?? '';
          if (newLyricUrl != oldLyricUrl) {
            if (newLyricUrl.isEmpty) {
              await repository.updateSongLyrics(
                widget.song!.id,
                lyricSource: '',
                lyric: '',
              );
            } else {
              await repository.updateSongLyrics(
                widget.song!.id,
                lyricSource: 'url',
                lyricRemoteUrl: newLyricUrl,
              );
            }
          }
        }
      } else if (isRadio) {
        // 创建电台
        await repository.createRadioSong(
          title: _titleController.text.trim(),
          artist:
              _artistController.text.trim().isEmpty
                  ? null
                  : _artistController.text.trim(),
          url: _urlController.text.trim(),
          coverUrl:
              _coverUrlController.text.trim().isEmpty
                  ? null
                  : _coverUrlController.text.trim(),
          isVideo: _isVideo,
        );
      } else {
        // 创建网络歌曲
        await repository.createRemoteSong(
          title: _titleController.text.trim(),
          artist:
              _artistController.text.trim().isEmpty
                  ? null
                  : _artistController.text.trim(),
          album:
              _albumController.text.trim().isEmpty
                  ? null
                  : _albumController.text.trim(),
          url: _urlController.text.trim(),
          coverUrl:
              _coverUrlController.text.trim().isEmpty
                  ? null
                  : _coverUrlController.text.trim(),
          duration: double.tryParse(_durationController.text),
          lyricRemoteUrl:
              _lyricUrlController.text.trim().isEmpty
                  ? null
                  : _lyricUrlController.text.trim(),
          isVideo: _isVideo,
        );
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ResponsiveSnackBar.show(
          context,
          message: isEditMode ? l10n.librarySaveSuccess : l10n.libraryAddSuccess,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).libraryOperationFailed('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
