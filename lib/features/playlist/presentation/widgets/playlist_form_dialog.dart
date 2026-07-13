import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../l10n/app_localizations.dart';
import 'playlist_cover_edit_mixin.dart';

class PlaylistFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? initialType;
  final String? initialCoverUrl;
  final int? playlistId;
  final bool isEdit;
  final bool isBuiltIn;

  const PlaylistFormDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialType,
    this.initialCoverUrl,
    this.playlistId,
    this.isEdit = false,
    this.isBuiltIn = false,
  });

  @override
  State<PlaylistFormDialog> createState() => PlaylistFormDialogState();
}

class PlaylistFormDialogState extends State<PlaylistFormDialog>
    with PlaylistCoverEditMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  @override
  String? get coverInitialUrl => widget.initialCoverUrl;

  @override
  int? get coverPickerPlaylistId => widget.playlistId;

  @override
  double get coverPlaceholderIconSize => 40;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _type = widget.initialType ?? AppConstants.playlistTypeNormal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasCover =
        coverMode != 'clear' &&
        (coverMode == 'local' ||
            coverMode == 'song' ||
            widget.initialCoverUrl?.isNotEmpty == true);
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 编辑模式显示封面选择
                if (widget.isEdit) ...[
                  // 封面预览区域
                  Container(
                    width: 100,
                    height: 100,
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
                        onPressed: pickCoverLocalImage,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(l10n.playlistUploadImage),
                      ),
                      OutlinedButton.icon(
                        onPressed: pickCoverFromSongs,
                        icon: const Icon(Icons.music_note, size: 18),
                        label: Text(l10n.playlistPickFromSongs),
                      ),
                      if (hasCover)
                        TextButton.icon(
                          onPressed: clearCoverSelection,
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
                ],
                // 歌单名称
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.playlistNameLabel,
                    hintText: l10n.playlistNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.playlistNameRequired;
                    }
                    return null;
                  },
                  autofocus: !widget.isEdit,
                  enabled: !widget.isBuiltIn,
                ),
                const SizedBox(height: 16),
                // 歌单描述
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.playlistDescLabel,
                    hintText: l10n.playlistDescHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: !widget.isBuiltIn,
                ),
                const SizedBox(height: 16),
                // 歌单类型（仅创建时可选）
                if (!widget.isEdit)
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: AppConstants.playlistTypeNormal,
                        label: Text(l10n.playlistTypeNormalOption),
                        icon: const Icon(Icons.queue_music),
                      ),
                      ButtonSegment(
                        value: AppConstants.playlistTypeRadio,
                        label: Text(l10n.playlistTypeRadioOption),
                        icon: const Icon(Icons.radio),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _type = selected.first;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.playlistOk)),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      final Map<String, dynamic> result = {
        'name': _nameController.text.trim(),
        'description':
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        'type': _type,
      };

      // 编辑模式时添加封面信息
      if (widget.isEdit) {
        result['coverMode'] = coverMode;
        result['localFile'] = coverLocalFile;
        result['selectedCoverUrl'] = coverSelectedUrl;
        result['selectedCoverSongId'] = coverSelectedSongId;
      }

      Navigator.of(context).pop(result);
    }
  }
}
