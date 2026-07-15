import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/filter_pill.dart';
import '../providers/category_provider.dart';

// 曲库统一浏览页的「视图」抽象。
//
// 视图 key 分两类：
// - 扁平列表视图：all/local/remote/radio（按 type 过滤歌曲列表，「网络」= remote）
// - 分类聚合视图：artist/album/genre/year/decade/language/style（facet 卡片网格 → 下钻）

/// 扁平列表视图的 key 集合。
const Set<String> flatLibraryViewKeys = {'all', 'local', 'remote', 'radio'};

/// 判断某视图是否为扁平列表视图（否则为分类聚合视图）。
bool isFlatLibraryView(String key) => flatLibraryViewKeys.contains(key);

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

/// 视图展示名称。facet 维度复用 categoryFieldLabel，扁平视图复用现有 type 文案。
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
    default:
      return Icons.label_outline;
  }
}

/// 窄屏顶部视图切换条：横向可滚动 FilterPill 行（沿用项目 FilterPill 范式，不用 TabBar）。
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < viewKeys.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            FilterPill(
              label: libraryViewLabel(l10n, viewKeys[i]),
              isSelected: selectedKey == viewKeys[i],
              onTap: () => onSelected(viewKeys[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 宽屏左侧视图导航栏：竖向列表，样式对齐 SettingsMasterDetail 的宽屏条目
/// （选中态 secondaryContainer + 圆形图标底 + 标题加粗），避免自造风格。
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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      itemCount: viewKeys.length,
      itemBuilder: (context, index) {
        final key = viewKeys[index];
        final isSelected = key == selectedKey;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            color: isSelected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
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
                            ? colorScheme.onSecondaryContainer
                                  .withValues(alpha: 0.12)
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
                          color: isSelected
                              ? colorScheme.onSecondaryContainer
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
