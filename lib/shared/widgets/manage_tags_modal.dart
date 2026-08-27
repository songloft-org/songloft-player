import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/song_tags_api.dart';
import '../../features/library/presentation/providers/song_tag_provider.dart';
import '../../l10n/app_localizations.dart';
import '../utils/responsive_snackbar.dart';

/// 管理歌曲标签的模态框
class ManageTagsModal extends ConsumerStatefulWidget {
  final List<int> songIds;

  const ManageTagsModal({super.key, required this.songIds});

  static Future<void> show(BuildContext context, {required List<int> songIds}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ManageTagsModal(songIds: songIds),
    );
  }

  @override
  ConsumerState<ManageTagsModal> createState() => _ManageTagsModalState();
}

class _ManageTagsModalState extends ConsumerState<ManageTagsModal> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<SongTag> _allTags = [];
  Set<int> _selectedTagIds = {};
  final _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(songTagsApiProvider);
      final resp = await api.list(limit: 200);
      final songTags = widget.songIds.length == 1
          ? await api.getSongTags(widget.songIds.first)
          : <SongTag>[];

      if (!mounted) return;
      setState(() {
        _allTags = resp.tags;
        _selectedTagIds = songTags.map((t) => t.id).toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ResponsiveSnackBar.showError(context, message: '$e');
      }
    }
  }

  Future<void> _createTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;

    try {
      final api = ref.read(songTagsApiProvider);
      final tag = await api.create(name: name);
      if (!mounted) return;
      setState(() {
        _allTags.insert(0, tag);
        _selectedTagIds.add(tag.id);
        _newTagController.clear();
      });
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '$e');
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(songTagsApiProvider);
      if (widget.songIds.length == 1) {
        await api.setSongTags(
          widget.songIds.first,
          _selectedTagIds.toList(),
        );
      } else {
        for (final tagId in _selectedTagIds) {
          await api.batchBind(tagId, widget.songIds);
        }
      }
      if (!mounted) return;
      ref.invalidate(songTagListProvider);
      for (final songId in widget.songIds) {
        ref.invalidate(songTagsForSongProvider(songId));
      }
      Navigator.of(context).pop();
      final l10n = AppLocalizations.of(context);
      ResponsiveSnackBar.show(context, message: l10n.librarySaveSuccess);
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    l10n.manageTags,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    TextButton(onPressed: _save, child: Text(l10n.librarySave)),
                ],
              ),
            ),
            const Divider(height: 1),
            // 创建新标签
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      decoration: InputDecoration(
                        hintText: l10n.createTagHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _createTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _createTag,
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 标签列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allTags.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noTags,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _allTags.length,
                          itemBuilder: (context, index) {
                            final tag = _allTags[index];
                            final selected = _selectedTagIds.contains(tag.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedTagIds.add(tag.id);
                                  } else {
                                    _selectedTagIds.remove(tag.id);
                                  }
                                });
                              },
                              title: Text(tag.name),
                              subtitle: Text(
                                '${tag.songCount} ${l10n.songCountUnit}',
                                style: theme.textTheme.bodySmall,
                              ),
                              secondary: tag.color.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 12,
                                      backgroundColor: _parseColor(tag.color),
                                    )
                                  : const Icon(Icons.label_outline),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(String hex) {
    if (hex.isEmpty) return Colors.grey;
    try {
      final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
      return Color(value | 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }
}
