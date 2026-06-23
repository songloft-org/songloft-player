import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/responsive_snackbar.dart';
import '../../data/settings_api.dart';
import '../providers/settings_provider.dart';

class MetadataRefreshManager extends ConsumerStatefulWidget {
  const MetadataRefreshManager({super.key});

  @override
  ConsumerState<MetadataRefreshManager> createState() =>
      _MetadataRefreshManagerState();
}

class _MetadataRefreshManagerState
    extends ConsumerState<MetadataRefreshManager> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(metadataRefreshProvider.notifier).refreshProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(metadataRefreshProvider);
    final theme = Theme.of(context);

    Widget refreshTile;
    if (progress.isRunning) {
      refreshTile = _buildRunningState(progress, theme);
    } else if (progress.isDone && progress.total > 0) {
      refreshTile = _buildDoneState(progress, theme);
    } else {
      refreshTile = _buildIdleState(theme);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRemoteTitleSourceTile(theme),
        refreshTile,
      ],
    );
  }

  Widget _buildRemoteTitleSourceTile(ThemeData theme) {
    final asyncValue = ref.watch(remoteTitleSourceProvider);
    final isTag = (asyncValue.value ?? 'filename') == 'tag';

    return SwitchListTile(
      secondary: Icon(
        Icons.title_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: const Text('使用标签覆盖标题'),
      subtitle: Text(
        isTag ? '网络歌曲元数据刷新时用音频标签覆盖标题' : '网络歌曲标题保持文件名，不使用标签覆盖',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: isTag,
      onChanged: asyncValue.isLoading
          ? null
          : (value) async {
              try {
                await ref
                    .read(remoteTitleSourceProvider.notifier)
                    .setValue(value ? 'tag' : 'filename');
                if (mounted) {
                  ResponsiveSnackBar.show(context, message: '已保存');
                }
              } catch (e) {
                if (mounted) {
                  ResponsiveSnackBar.showError(
                    context,
                    message: '保存失败: $e',
                  );
                }
              }
            },
    );
  }

  Widget _buildIdleState(ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.library_music_outlined,
        color: theme.colorScheme.primary,
      ),
      title: const Text('刷新网络歌曲元数据'),
      subtitle: const Text('探测所有元数据缺失的网络歌曲'),
      trailing: FilledButton.tonal(
        onPressed: () {
          ref.read(metadataRefreshProvider.notifier).startRefresh();
        },
        child: const Text('开始'),
      ),
    );
  }

  Widget _buildRunningState(
    MetadataRefreshProgress progress,
    ThemeData theme,
  ) {
    final label = progress.total > 0
        ? '${progress.completedCount} / ${progress.total}'
        : '准备中...';
    return ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: progress.total > 0 ? progress.progress : null,
        ),
      ),
      title: const Text('正在刷新元数据'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.total > 0 ? progress.progress : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
      trailing: TextButton(
        onPressed: () {
          ref.read(metadataRefreshProvider.notifier).cancel();
        },
        child: const Text('取消'),
      ),
    );
  }

  Widget _buildDoneState(MetadataRefreshProgress progress, ThemeData theme) {
    final statusText = progress.status == 'cancelled'
        ? '已取消'
        : progress.status == 'failed'
            ? '执行失败'
            : '已完成';
    final detail =
        '成功 ${progress.processed} 首${progress.failed > 0 ? '，失败 ${progress.failed} 首' : ''}';
    return ListTile(
      leading: Icon(
        progress.status == 'done' ? Icons.check_circle : Icons.info_outlined,
        color: progress.status == 'done'
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text('刷新元数据$statusText'),
      subtitle: Text(detail),
      trailing: FilledButton.tonal(
        onPressed: () {
          ref.read(metadataRefreshProvider.notifier).startRefresh();
        },
        child: const Text('重新刷新'),
      ),
    );
  }
}
