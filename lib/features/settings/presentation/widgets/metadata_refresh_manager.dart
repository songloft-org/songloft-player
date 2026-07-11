import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final asyncValue = ref.watch(remoteTitleSourceProvider);
    final isTag = (asyncValue.value ?? 'filename') == 'tag';

    return SwitchListTile(
      secondary: Icon(
        Icons.title_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.settingsMetadataUseTagTitle),
      subtitle: Text(
        isTag
            ? l10n.settingsMetadataUseTagOn
            : l10n.settingsMetadataUseTagOff,
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
                  ResponsiveSnackBar.show(context,
                      message: AppLocalizations.of(context)
                          .settingsMetadataSaved);
                }
              } catch (e) {
                if (mounted) {
                  ResponsiveSnackBar.showError(
                    context,
                    message: AppLocalizations.of(context)
                        .settingsMetadataSaveFailed(e.toString()),
                  );
                }
              }
            },
    );
  }

  Widget _buildIdleState(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        Icons.library_music_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(l10n.settingsMetadataRefreshTitle),
      subtitle: Text(l10n.settingsMetadataRefreshSubtitle),
      trailing: FilledButton.tonal(
        onPressed: () {
          ref.read(metadataRefreshProvider.notifier).startRefresh();
        },
        child: Text(l10n.settingsMetadataStart),
      ),
    );
  }

  Widget _buildRunningState(
    MetadataRefreshProgress progress,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    final label = progress.total > 0
        ? '${progress.completedCount} / ${progress.total}'
        : l10n.settingsMetadataPreparing;
    return ListTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: progress.total > 0 ? progress.progress : null,
        ),
      ),
      title: Text(l10n.settingsMetadataRefreshing),
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
        child: Text(l10n.commonCancel),
      ),
    );
  }

  Widget _buildDoneState(MetadataRefreshProgress progress, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final statusText = progress.status == 'cancelled'
        ? l10n.settingsMetadataStatusCancelled
        : progress.status == 'failed'
            ? l10n.settingsMetadataStatusFailed
            : l10n.settingsMetadataStatusDone;
    final detail = l10n.settingsMetadataSuccess(progress.processed) +
        (progress.failed > 0
            ? l10n.settingsMetadataFailedCount(progress.failed)
            : '');
    return ListTile(
      leading: Icon(
        progress.status == 'done' ? Icons.check_circle : Icons.info_outlined,
        color: progress.status == 'done'
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(l10n.settingsMetadataRefreshResult(statusText)),
      subtitle: Text(detail),
      trailing: FilledButton.tonal(
        onPressed: () {
          ref.read(metadataRefreshProvider.notifier).startRefresh();
        },
        child: Text(l10n.settingsMetadataRefreshAgain),
      ),
    );
  }
}
