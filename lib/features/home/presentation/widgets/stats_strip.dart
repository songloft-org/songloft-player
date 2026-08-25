import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/library_stats.dart';
import '../../../library/presentation/providers/songs_provider.dart';

/// 面板内各层之间的纵向间距（12px）
///
/// AppSpacing 没有 12 这一档：md(16) 会让四层堆出来的卡片明显偏高，sm(8) 又太挤。
const double _tierGap = AppSpacing.sm + AppSpacing.xs;

/// 曲库统计面板
///
/// 数据来自 `GET /api/v1/songs/stats`（[libraryStatsProvider]），四层纵向排列：
/// 1. headline —— 歌曲总数（大号粗体）+「首歌曲」label，右侧是曲库总时长
/// 2. 本地 / 网络 / 电台 的歌曲数
/// 3. 歌手 / 专辑 / 流派 的去重计数
/// 4. footer —— 本地文件占用空间，**仅当非零时渲染**：全远程曲库返回 0 字节，
///    显示「0 B」是噪音而不是信息
///
/// 改造前这里显示的是两个 section 的歌单数 / 电台数 / 总计——看着像曲库汇总、其实
/// 只是歌单计数；现在读真正的统计端点。
class StatsStrip extends ConsumerWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 加载中与失败都降级为全零，不做骨架屏、也不整块消失：面板在页面最底部、属于
    // 补充信息，骨架屏的高度跳变或请求失败时整块抽走导致下方内容上跳，都比数字暂时
    // 为 0 更扰人。AsyncValue.value 是可空 getter，AsyncError 且无历史值时返回 null
    // 而不抛；invalidate 触发的刷新会保留旧值，所以下拉刷新期间数字不会闪回 0。
    final stats = ref.watch(libraryStatsProvider).value ?? LibraryStats.empty;

    final (:hours, :minutes) = Formatters.splitCoarseDuration(
      stats.totalDuration,
    );
    final duration =
        hours > 0
            ? l10n.homeStatDurationHm(hours, minutes)
            : l10n.homeStatDurationM(minutes);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // 描边卡片而非 primaryContainer 实心块：这一屏已经有歌单封面和插件网格等
          // 视觉重点，统计面板是补充信息，填高饱和主色会盖过上方内容。
          color: colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 第 1 层：歌曲总数 + 总时长 ──────────────────────────────
            Row(
              children: [
                // 数字与 label 走 baseline 对齐（不是 center）：大号数字与小号 label
                // 居中对齐会让 label 视觉上偏高。Expanded + Flexible 保证空间不足时
                // ellipsis 落在 label 上，数字永远完整可见。
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        stats.totalSongs.toString(),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          l10n.homeStatSongs,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.music_note_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  duration,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // ── 第 2 层：按歌曲来源拆分 ─────────────────────────────────
            const SizedBox(height: _tierGap),
            _StatRow(
              cells: [
                (label: l10n.songTypeLocal, value: stats.localSongs),
                (label: l10n.songTypeRemote, value: stats.remoteSongs),
                (label: l10n.songTypeRadio, value: stats.radioSongs),
              ],
            ),

            // ── 第 3 层：曲库维度 ──────────────────────────────────────
            const SizedBox(height: _tierGap),
            _StatRow(
              cells: [
                (label: l10n.categoryFieldArtist, value: stats.artistCount),
                (label: l10n.categoryFieldAlbum, value: stats.albumCount),
                (label: l10n.categoryFieldGenre, value: stats.genreCount),
              ],
            ),

            // ── 第 4 层：占用空间（仅本地文件真占空间时才有意义）──────────
            if (stats.hasFileSize) ...[
              const SizedBox(height: _tierGap),
              Center(
                child: Text(
                  l10n.homeStatSize(
                    Formatters.formatFileSize(stats.totalFileSize),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    // 比 label 再弱一档：这是整个面板里优先级最低的一行信息。
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 等宽三格的一行
///
/// 每格用 [Expanded] 而非 `spaceBetween`：等宽才能让上下两行的数值竖向对齐，
/// 否则两行会因各自文字宽度不同而错列。
class _StatRow extends StatelessWidget {
  final List<({String label, int value})> cells;

  const _StatRow({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final cell in cells)
          Expanded(child: _StatCell(label: cell.label, value: cell.value)),
      ],
    );
  }
}

/// 单格：数值在上、label 在下，整体居中
class _StatCell extends StatelessWidget {
  final String label;
  final int value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          // 刻意不加千分位分隔符：项目没有对应的格式化工具，为一个统计面板引入
          // NumberFormat 的本地化差异（1,234 / 1 234）不值得。
          value.toString(),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
