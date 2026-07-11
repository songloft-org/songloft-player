import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../l10n/app_localizations.dart';

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
                  _FilterChip(
                    label: l10n.filterAll,
                    isSelected: currentType == null,
                    onTap: () => onTypeChanged(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.songTypeLocal,
                    isSelected: currentType == AppConstants.songTypeLocal,
                    onTap: () => onTypeChanged(AppConstants.songTypeLocal),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: l10n.songTypeRemote,
                    isSelected: currentType == AppConstants.songTypeRemote,
                    onTap: () => onTypeChanged(AppConstants.songTypeRemote),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: isSelected
            ? BorderSide.none
            : BorderSide(color: colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check,
                  size: 16,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
