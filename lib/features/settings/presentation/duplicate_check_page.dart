import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../data/scan_api.dart';
import 'providers/settings_provider.dart';

class DuplicateCheckPage extends ConsumerStatefulWidget {
  const DuplicateCheckPage({super.key});

  @override
  ConsumerState<DuplicateCheckPage> createState() => _DuplicateCheckPageState();
}

enum _PagePhase { status, computing, results }

class _DuplicateCheckPageState extends ConsumerState<DuplicateCheckPage> {
  _PagePhase _phase = _PagePhase.status;
  FingerprintStatus? _status;
  FingerprintProgress? _progress;
  DuplicatesResult? _duplicates;
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;

  // key = group index, value = selected song id (to keep)
  final Map<int, int> _selectedKeep = {};
  final Set<int> _ignoredGroups = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(scanApiProvider);
      final status = await api.getFingerprintStatus();
      if (!mounted) return;

      try {
        final progress = await api.getFingerprintProgress();
        if (!mounted) return;
        if (progress.isRunning) {
          setState(() {
            _status = status;
            _progress = progress;
            _phase = _PagePhase.computing;
            _loading = false;
          });
          _startPolling();
          return;
        }
      } catch (_) {}

      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _startCompute({bool recomputeAll = false}) async {
    setState(() {
      _error = null;
    });
    try {
      final api = ref.read(scanApiProvider);
      await api.startFingerprintCompute(recomputeAll: recomputeAll);
      if (!mounted) return;
      setState(() => _phase = _PagePhase.computing);
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final api = ref.read(scanApiProvider);
        final progress = await api.getFingerprintProgress();
        if (!mounted) return;
        setState(() => _progress = progress);
        if (progress.isDone) {
          _pollTimer?.cancel();
          _loadDuplicates();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadDuplicates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(scanApiProvider);
      final result = await api.getDuplicates();
      if (!mounted) return;
      _selectedKeep.clear();
      _ignoredGroups.clear();
      for (int i = 0; i < result.groups.length; i++) {
        _selectedKeep[i] = _recommendedSongId(result.groups[i]);
      }
      setState(() {
        _duplicates = result;
        _phase = _PagePhase.results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  int _recommendedSongId(DuplicateGroup group) {
    var best = group.songs.first;
    for (final s in group.songs) {
      if (s.bitRate > best.bitRate) best = s;
    }
    return best.id;
  }

  Future<void> _deleteGroupDuplicates(int groupIndex) async {
    final group = _duplicates!.groups[groupIndex];
    final keepId = _selectedKeep[groupIndex] ?? _recommendedSongId(group);
    final toDelete = group.songs.where((s) => s.id != keepId).toList();
    if (toDelete.isEmpty) return;

    final confirmed = await _showDeleteConfirm(toDelete.length);
    if (confirmed != true || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '${AppConfig.apiPrefix}/songs/batch-delete',
        data: {
          'ids': toDelete.map((s) => s.id).toList(),
          'delete_files': true,
        },
      );
      if (!mounted) return;
      ResponsiveSnackBar.show(context,
          message: AppLocalizations.of(context).settingsDuplicateDeleted(toDelete.length));
      _loadDuplicates();
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context,
          message: AppLocalizations.of(context).settingsDuplicateDeleteFailed('$e'));
    }
  }

  Future<void> _deleteAllDuplicates() async {
    if (_duplicates == null || _duplicates!.groups.isEmpty) return;

    final allToDelete = <int>[];
    for (int i = 0; i < _duplicates!.groups.length; i++) {
      if (_ignoredGroups.contains(i)) continue;
      final group = _duplicates!.groups[i];
      final keepId = _selectedKeep[i] ?? _recommendedSongId(group);
      for (final s in group.songs) {
        if (s.id != keepId) allToDelete.add(s.id);
      }
    }
    if (allToDelete.isEmpty) return;

    final confirmed = await _showDeleteConfirm(allToDelete.length);
    if (confirmed != true || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '${AppConfig.apiPrefix}/songs/batch-delete',
        data: {
          'ids': allToDelete,
          'delete_files': true,
        },
      );
      if (!mounted) return;
      ResponsiveSnackBar.show(context,
          message: AppLocalizations.of(context).settingsDuplicateDeleted(allToDelete.length));
      _loadDuplicates();
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context,
          message: AppLocalizations.of(context).settingsDuplicateDeleteFailed('$e'));
    }
  }

  Future<bool?> _showDeleteConfirm(int count) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDuplicateConfirmTitle),
        content: Text(l10n.settingsDuplicateConfirmMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.settingsDuplicateConfirmTitle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDuplicateTitle)),
      body: _loading && _phase == _PagePhase.status
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (_error != null) _buildError(),
                if (_phase == _PagePhase.status) _buildStatusPhase(),
                if (_phase == _PagePhase.computing) _buildComputingPhase(),
                if (_phase == _PagePhase.results) _buildResultsPhase(),
              ],
            ),
    );
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!, style: TextStyle(color: colorScheme.onErrorContainer)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.settingsDuplicateDismissError,
              onPressed: () => setState(() => _error = null),
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPhase() {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final status = _status;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsDuplicateIntro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (status != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.settingsDuplicateFingerprintStats,
                          style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statRow(l10n.settingsDuplicateLocalSongs,
                      l10n.settingsDuplicateSongCount(status.total)),
                  _statRow(l10n.settingsDuplicateComputed,
                      l10n.settingsDuplicateSongCount(status.computed)),
                  _statRow(l10n.settingsDuplicatePending,
                      l10n.settingsDuplicateSongCount(status.missing)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!status.chromaprintAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.settingsDuplicateChromaprintMissing,
                      style: TextStyle(color: colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: status.chromaprintAvailable
                  ? (status.missing > 0 ? _startCompute : _loadDuplicates)
                  : null,
              icon: const Icon(Icons.fingerprint),
              label: Text(status.missing > 0
                  ? l10n.settingsDuplicateStartCompute
                  : l10n.settingsDuplicateCheck),
            ),
          ),
          if (status.chromaprintAvailable && status.computed > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _startCompute(recomputeAll: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.settingsDuplicateRecomputeAll),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildComputingPhase() {
    final progress = _progress;
    final total = progress?.total ?? _status?.missing ?? 0;
    final computed = progress?.computed ?? 0;
    final ratio = total > 0 ? computed / total : 0.0;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.settingsDuplicateComputing(computed, total),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (progress != null && progress.failed > 0)
          Text(
            l10n.settingsDuplicateFailed(progress.failed),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsDuplicateAutoDetect,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPhase() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final duplicates = _duplicates;
    if (duplicates == null || duplicates.groups.isEmpty) {
      return _buildNoResults();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultsSummary(duplicates),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < duplicates.groups.length; i++) ...[
          _buildGroupCard(i, duplicates.groups[i]),
          const SizedBox(height: AppSpacing.md),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _recheck,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).settingsDuplicateRecheck),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildNoResults() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.check_circle_outline, size: 64, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.settingsDuplicateNoResults,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsDuplicateNoResultsHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _recheck,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.settingsDuplicateRecheck),
        ),
      ],
    );
  }

  Widget _buildResultsSummary(DuplicatesResult duplicates) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalToDelete = _countTotalToDelete();
    final ignoredCount = _ignoredGroups.length;
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsDuplicateSummary(
                  duplicates.totalGroups, duplicates.totalDuplicates),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            if (ignoredCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.settingsDuplicateIgnoredCount(ignoredCount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
            if (totalToDelete > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _deleteAllDuplicates,
                  icon: const Icon(Icons.delete_sweep),
                  label: Text(l10n.settingsDuplicateCleanAll(totalToDelete)),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _countTotalToDelete() {
    if (_duplicates == null) return 0;
    int count = 0;
    for (int i = 0; i < _duplicates!.groups.length; i++) {
      if (_ignoredGroups.contains(i)) continue;
      final keepId = _selectedKeep[i] ?? _recommendedSongId(_duplicates!.groups[i]);
      count += _duplicates!.groups[i].songs.where((s) => s.id != keepId).length;
    }
    return count;
  }

  Widget _buildGroupCard(int groupIndex, DuplicateGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final keepId = _selectedKeep[groupIndex] ?? _recommendedSongId(group);
    final recommendedId = _recommendedSongId(group);
    final isIgnored = _ignoredGroups.contains(groupIndex);
    final l10n = AppLocalizations.of(context);

    return Opacity(
      opacity: isIgnored ? 0.5 : 1.0,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsDuplicateGroupLabel(groupIndex + 1),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (isIgnored) {
                          _ignoredGroups.remove(groupIndex);
                        } else {
                          _ignoredGroups.add(groupIndex);
                        }
                      });
                    },
                    icon: Icon(
                      isIgnored ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    tooltip: isIgnored
                        ? l10n.settingsDuplicateUnignore
                        : l10n.settingsDuplicateIgnore,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (!isIgnored) ...[
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: keepId,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedKeep[groupIndex] = v);
                  },
                  child: Column(
                    children: [
                      for (final song in group.songs) ...[
                        _buildSongTile(groupIndex, song, keepId, recommendedId),
                        if (song != group.songs.last) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteGroupDuplicates(groupIndex),
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    label: Text(
                      l10n.settingsDuplicateDeleteUnselected,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(int groupIndex, DuplicateSong song, int keepId, int recommendedId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = song.id == keepId;
    final isRecommended = song.id == recommendedId;

    return InkWell(
      onTap: () => setState(() => _selectedKeep[groupIndex] = song.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<int>(
              value: song.id,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${song.title} - ${song.artist}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context).settingsDuplicateRecommended,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.filePath,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.format.toUpperCase()} · ${song.bitRate}kbps · ${song.fileSizeDisplay}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recheck() {
    setState(() {
      _phase = _PagePhase.status;
      _duplicates = null;
      _progress = null;
    });
    _loadStatus();
  }
}
