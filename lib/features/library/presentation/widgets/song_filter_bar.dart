import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/filter_pill.dart';

/// 歌曲类型筛选栏
class SongFilterBar extends StatelessWidget {
  final String? currentType;
  final ValueChanged<String?> onTypeChanged;
  final int songCount;

  const SongFilterBar({
    super.key,
    this.currentType,
    required this.onTypeChanged,
    this.songCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 筛选 Chips（可滚动）
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterPill(
                    label: l10n.filterAll,
                    isSelected: currentType == null,
                    onTap: () => onTypeChanged(null),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: l10n.songTypeLocal,
                    isSelected: currentType == AppConstants.songTypeLocal,
                    onTap: () => onTypeChanged(AppConstants.songTypeLocal),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: l10n.songTypeRemote,
                    isSelected: currentType == AppConstants.songTypeRemote,
                    onTap: () => onTypeChanged(AppConstants.songTypeRemote),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: l10n.songTypeRadio,
                    isSelected: currentType == AppConstants.songTypeRadio,
                    onTap: () => onTypeChanged(AppConstants.songTypeRadio),
                  ),
                ],
              ),
            ),
          ),
          // 歌曲总数
          if (songCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                l10n.librarySongCount(songCount),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
