import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/models/artist.dart';
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
  final List<TextEditingController> _artistControllers = [];
  late final TextEditingController _albumController;
  late final TextEditingController _urlController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _durationController;
  late final TextEditingController _lyricUrlController;
  bool _isSubmitting = false;
  bool _renameFile = true; // 本地歌曲：改标题时同步重命名文件，默认开启
  bool _isVideo = false; // 网络歌曲/电台：是否含视频画面（不走扫描 ffprobe，需手动声明）
  RadioMode _radioMode = RadioMode.automatic;

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
    // 先用 songs.artist 显示串占位回显（保证进入页面即有内容，不空）；
    // 编辑模式下异步拉取结构化 song_artists 覆盖为分行歌手。
    _artistControllers.add(
      TextEditingController(text: widget.song?.artist ?? ''),
    );
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
    _radioMode = widget.song?.radioMode ?? RadioMode.automatic;
    if (isEditMode) {
      _loadSongArtists();
    }
  }

  /// 编辑模式：异步拉取结构化参与歌手（role=artist），用其名字覆盖成多行，
  /// 使对唱歌曲回显为分行歌手而非合并串。拉取为空则保留占位回显不动。
  Future<void> _loadSongArtists() async {
    try {
      final repository = ref.read(songsRepositoryProvider);
      final artists = await repository.getSongArtists(widget.song!.id);
      final names =
          artists
              .where((a) => a.role == ArtistRole.artist)
              .map((a) => a.artist.name)
              .where((n) => n.isNotEmpty)
              .toList();
      if (!mounted) return;
      if (names.isEmpty) return; // 无结构化数据，保留占位回显
      for (final c in _artistControllers) {
        c.dispose();
      }
      _artistControllers.clear();
      for (final name in names) {
        _artistControllers.add(TextEditingController(text: name));
      }
      setState(() {});
    } catch (_) {
      // 拉取失败不影响编辑（保留占位回显），静默忽略
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _artistControllers) {
      c.dispose();
    }
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
                          _buildReadOnlyUrlRow(
                            l10n.libraryPlay,
                            widget.song!.url,
                          ),
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

              // 参与歌手（多行：对唱/合唱分行填写，支持按任一歌手检索）
              _buildArtistEditors(l10n),
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
                      labelText:
                          isEditMode
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
                    labelText:
                        isEditMode
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
                      labelText:
                          isEditMode
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

                if (isRadio)
                  DropdownButtonFormField<RadioMode>(
                    initialValue: _radioMode,
                    decoration: InputDecoration(
                      labelText: l10n.libraryRadioMode,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: RadioMode.automatic,
                        child: Text(l10n.libraryRadioModeAuto),
                      ),
                      DropdownMenuItem(
                        value: RadioMode.hls,
                        child: Text(l10n.libraryRadioModeHls),
                      ),
                      DropdownMenuItem(
                        value: RadioMode.flv,
                        child: Text(l10n.libraryRadioModeFlv),
                      ),
                      DropdownMenuItem(
                        value: RadioMode.audioOnly,
                        child: Text(l10n.libraryRadioModeAudioOnly),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _radioMode = value);
                    },
                  ),
                if (!isRadio || _radioMode != RadioMode.audioOnly)
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
                  final previewUrl =
                      isEditMode
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
                              UrlHelper.buildCoverUrl(previewUrl, width: 300),
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

  Widget _buildArtistEditors(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.libraryColumnArtist,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22),
              tooltip: l10n.libraryEditArtistsAdd,
              onPressed: _isSubmitting ? null : _addArtistField,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.libraryEditArtistsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _artistControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _artistControllers[i],
                    decoration: InputDecoration(
                      hintText: l10n.libraryEditArtistHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                if (_artistControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    tooltip: l10n.libraryEditArtistsRemove,
                    onPressed:
                        _isSubmitting ? null : () => _removeArtistField(i),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _addArtistField() {
    setState(() {
      _artistControllers.add(TextEditingController());
    });
  }

  void _removeArtistField(int index) {
    if (_artistControllers.length <= 1) return;
    setState(() {
      final c = _artistControllers.removeAt(index);
      c.dispose();
    });
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // 多歌手：收集非空行 → 显示串（"A & B"）+ 结构化输入（用于 setSongArtists）
    final artistNames =
        _artistControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    final displayArtist = artistNames.join(' & ');
    final artistInputs =
        artistNames
            .asMap()
            .entries
            .map(
              (e) => ArtistInput(
                name: e.value,
                role: ArtistRole.artist,
                position: e.key,
              ),
            )
            .toList();

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
          artist: displayArtist,
          album: _albumController.text.trim(),
          renameFile: _renameFile,
        );
        // 同步结构化参与歌手（song_artists），使按任一歌手都能检索到该歌。
        await repository.setSongArtists(widget.song!.id, artistInputs);
      } else if (isEditMode) {
        // 更新歌曲
        await repository.updateSong(
          widget.song!.id,
          title: _titleController.text.trim(),
          artist: displayArtist.isEmpty ? null : displayArtist,
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
          isVideo: _isVideo && _radioMode != RadioMode.audioOnly,
          radioMode:
              isRadio && _radioMode != widget.song!.radioMode
                  ? _radioMode
                  : null,
        );
        // 同步结构化参与歌手（song_artists）。
        await repository.setSongArtists(widget.song!.id, artistInputs);

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
          artist: displayArtist.isEmpty ? null : displayArtist,
          url: _urlController.text.trim(),
          coverUrl:
              _coverUrlController.text.trim().isEmpty
                  ? null
                  : _coverUrlController.text.trim(),
          isVideo: _isVideo && _radioMode != RadioMode.audioOnly,
          radioMode: _radioMode,
        );
      } else {
        // 创建网络歌曲
        await repository.createRemoteSong(
          title: _titleController.text.trim(),
          artist: displayArtist.isEmpty ? null : displayArtist,
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
          message:
              isEditMode ? l10n.librarySaveSuccess : l10n.libraryAddSuccess,
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
