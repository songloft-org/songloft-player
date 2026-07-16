import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/filter_pill.dart';
import '../providers/category_provider.dart';

// 曲库统一浏览页的「视图」抽象。
//
// 视图 key 分三组（渲染时按固定组顺序展示并在组间加分割线，组内顺序沿用用户配置）：
// - 歌曲组：all/local/remote/radio（按 type 过滤的扁平歌曲列表，「网络」= remote）
// - 分类组：artist/album/genre/year/decade/language/style（facet 卡片 → 下钻）
// - 歌单组：playlist/playlist_normal/playlist_radio（歌单卡片列表 → 歌单详情）

/// 扁平列表视图的 key 集合。
const Set<String> flatLibraryViewKeys = {'all', 'local', 'remote', 'radio'};

/// 歌单视图的 key 集合。
const Set<String> playlistLibraryViewKeys = {
  'playlist',
  'playlist_normal',
  'playlist_radio',
};

/// 判断某视图是否为扁平歌曲列表视图。
bool isFlatLibraryView(String key) => flatLibraryViewKeys.contains(key);

/// 判断某视图是否为歌单视图。
bool isPlaylistLibraryView(String key) => playlistLibraryViewKeys.contains(key);

/// 扁平视图对应的歌曲 type 过滤值；all 返回 null（不过滤）。
String? flatViewType(String key) {
  switch (key) {
    case 'local':
      return AppConstants.songTypeLocal;
    case 'remote':
      return AppConstants.songTypeRemote;
    case 'radio':
      return AppConstants.songTypeRadio;
    default:
      return null; // all
  }
}

/// 歌单视图对应的歌单 type 过滤值；playlist 返回 null（全部歌单）。
String? playlistViewType(String key) {
  switch (key) {
    case 'playlist_normal':
      return AppConstants.playlistTypeNormal;
    case 'playlist_radio':
      return AppConstants.playlistTypeRadio;
    default:
      return null; // playlist（全部）
  }
}

/// 视图展示名称。facet 维度复用 categoryFieldLabel，其余复用现有文案。
String libraryViewLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'all':
      return l10n.filterAll;
    case 'local':
      return l10n.songTypeLocal;
    case 'remote':
      return l10n.songTypeRemote;
    case 'radio':
      return l10n.songTypeRadio;
    case 'playlist':
      return l10n.libraryViewPlaylistAll;
    case 'playlist_normal':
      return l10n.playlistFilterNormal;
    case 'playlist_radio':
      return l10n.playlistFilterRadio;
    default:
      return categoryFieldLabel(l10n, key);
  }
}

/// 视图图标。
IconData libraryViewIcon(String key) {
  switch (key) {
    case 'all':
      return Icons.library_music;
    case 'local':
      return Icons.folder_outlined;
    case 'remote':
      return Icons.cloud_outlined;
    case 'radio':
      return Icons.radio;
    case 'artist':
      return Icons.person_outline;
    case 'album':
      return Icons.album_outlined;
    case 'genre':
      return Icons.category_outlined;
    case 'year':
      return Icons.calendar_today_outlined;
    case 'decade':
      return Icons.date_range_outlined;
    case 'language':
      return Icons.language_outlined;
    case 'style':
      return Icons.brush_outlined;
    case 'playlist':
      return Icons.queue_music;
    case 'playlist_normal':
      return Icons.playlist_play;
    case 'playlist_radio':
      return Icons.radio;
    default:
      return Icons.label_outline;
  }
}

/// 视图分组（固定组顺序：歌曲 → 分类 → 歌单）。
enum LibraryViewGroup { songs, facets, playlists }

LibraryViewGroup libraryViewGroup(String key) {
  if (isPlaylistLibraryView(key)) return LibraryViewGroup.playlists;
  if (isFlatLibraryView(key)) return LibraryViewGroup.songs;
  return LibraryViewGroup.facets;
}

/// 把视图 key 按固定组顺序归类，组内保留传入的相对顺序，仅返回非空组。
List<List<String>> groupLibraryViewKeys(List<String> keys) {
  final buckets = <LibraryViewGroup, List<String>>{
    LibraryViewGroup.songs: [],
    LibraryViewGroup.facets: [],
    LibraryViewGroup.playlists: [],
  };
  for (final k in keys) {
    buckets[libraryViewGroup(k)]!.add(k);
  }
  return [
    for (final g in LibraryViewGroup.values)
      if (buckets[g]!.isNotEmpty) buckets[g]!,
  ];
}

/// 窄屏顶部视图切换条：横向可滚动 FilterPill 行，按组分段并在组间加竖向分隔。
class LibraryViewSwitcher extends StatelessWidget {
  final List<String> viewKeys;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const LibraryViewSwitcher({
    super.key,
    required this.viewKeys,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final groups = groupLibraryViewKeys(viewKeys);

    final children = <Widget>[];
    for (var gi = 0; gi < groups.length; gi++) {
      if (gi > 0) {
        children.add(
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            color: colorScheme.outlineVariant,
          ),
        );
      }
      final group = groups[gi];
      for (var i = 0; i < group.length; i++) {
        if (i > 0) children.add(const SizedBox(width: AppSpacing.sm));
        children.add(
          FilterPill(
            label: libraryViewLabel(l10n, group[i]),
            isSelected: selectedKey == group[i],
            onTap: () => onSelected(group[i]),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(children: children),
    );
  }
}

/// 宽屏左侧视图导航栏：竖向列表，按组分段并在组间加横向分割线。
/// 样式对齐 SettingsMasterDetail 的宽屏条目（选中态 secondaryContainer + 圆形图标底）。
class LibraryViewRail extends StatelessWidget {
  final List<String> viewKeys;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const LibraryViewRail({
    super.key,
    required this.viewKeys,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupLibraryViewKeys(viewKeys);

    final children = <Widget>[];
    for (var gi = 0; gi < groups.length; gi++) {
      if (gi > 0) {
        children.add(
          const Divider(height: AppSpacing.md, indent: 12, endIndent: 12),
        );
      }
      for (final key in groups[gi]) {
        children.add(_buildItem(context, key));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      children: children,
    );
  }

  Widget _buildItem(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = key == selectedKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () => onSelected(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer.withValues(
                            alpha: 0.12,
                          )
                        : colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    libraryViewIcon(key),
                    size: 20,
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    libraryViewLabel(l10n, key),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      color: isSelected ? colorScheme.onSecondaryContainer : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
